// Contact Relationship Graph — models contacts as nodes in a weighted
// undirected graph.  Edges represent shared list memberships between
// contacts (weight = number of shared lists).
//
// Implements:
//   • Adjacency-list graph representation using hash maps
//   • BFS (breadth-first search) for connected-component discovery
//   • Dijkstra's shortest-path algorithm for relationship-chain finding
//   • Firestore integration — builds the graph from Contact Directories
//     and persists analytics to user_settings/graph_analytics
//
// AQA Group A: Graphs, Graph traversal, Complex optimisation algorithm

import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Graph node — one per contact
// ---------------------------------------------------------------------------

/// Represents a single contact in the relationship graph.
/// Each node stores its adjacency list as a hash map of
/// {neighbourId → edge weight}.
class GraphNode {
  final String contactId;
  final String contactName;
  final String phoneNumber;

  /// Adjacency list — maps neighbour contactId → edge weight.
  /// Weight = number of lists both contacts share.
  final Map<String, double> edges;

  GraphNode({
    required this.contactId,
    required this.contactName,
    required this.phoneNumber,
    Map<String, double>? edges,
  }) : edges = edges ?? {};

  /// Degree of this node (number of direct neighbours).
  int get degree => edges.length;

  @override
  String toString() => 'GraphNode($contactName, degree=$degree)';
}

// ---------------------------------------------------------------------------
// Weighted undirected graph
// ---------------------------------------------------------------------------

/// A weighted undirected graph of contacts.  Two contacts are connected
/// if they share at least one list; the edge weight equals the number
/// of shared lists (higher weight = stronger relationship).
class ContactGraph {
  /// All nodes keyed by contactId.
  final Map<String, GraphNode> _nodes = {};

  // ---- Basic accessors ----

  int get nodeCount => _nodes.length;

  int get edgeCount {
    int total = 0;
    for (final node in _nodes.values) {
      total += node.edges.length;
    }
    // Each undirected edge is stored twice (once per endpoint).
    return total ~/ 2;
  }

  /// Returns an unmodifiable view of all nodes.
  Map<String, GraphNode> get nodes => Map.unmodifiable(_nodes);

  /// Retrieve a node by its contact ID, or null if not present.
  GraphNode? getNode(String contactId) => _nodes[contactId];

  // ---- Mutation ----

  /// Add a node to the graph.  If it already exists the call is ignored.
  void addNode(GraphNode node) {
    _nodes.putIfAbsent(node.contactId, () => node);
  }

  /// Add a weighted undirected edge between two existing nodes.
  /// If either node is missing the call is a no-op.
  void addEdge(String fromId, String toId, double weight) {
    final from = _nodes[fromId];
    final to = _nodes[toId];
    if (from == null || to == null) return;

    // Undirected — store in both directions.
    from.edges[toId] = weight;
    to.edges[fromId] = weight;
  }

  /// Remove a node and all edges referencing it.
  void removeNode(String contactId) {
    final node = _nodes.remove(contactId);
    if (node == null) return;
    // Remove reverse edges in all neighbours.
    for (final neighbourId in node.edges.keys) {
      _nodes[neighbourId]?.edges.remove(contactId);
    }
  }

  // ---- BFS (breadth-first search) ----

  /// Performs a breadth-first search starting from [startId].
  /// Returns the list of contact IDs in the order they were visited.
  ///
  /// Uses a FIFO queue (Dart's [Queue]) for the frontier.
  List<String> bfs(String startId) {
    if (!_nodes.containsKey(startId)) return [];

    final visited = <String>{};
    final queue = Queue<String>(); // FIFO queue
    final order = <String>[];

    visited.add(startId);
    queue.add(startId);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      order.add(current);

      final neighbours = _nodes[current]?.edges.keys ?? [];
      for (final neighbourId in neighbours) {
        if (!visited.contains(neighbourId)) {
          visited.add(neighbourId);
          queue.add(neighbourId);
        }
      }
    }

    return order;
  }

  /// Finds all connected components in the graph using repeated BFS.
  /// Returns a list of components, each being a list of contact IDs.
  List<List<String>> getConnectedComponents() {
    final visited = <String>{};
    final components = <List<String>>[];

    for (final nodeId in _nodes.keys) {
      if (!visited.contains(nodeId)) {
        final component = bfs(nodeId);
        visited.addAll(component);
        components.add(component);
      }
    }

    return components;
  }

  // ---- Dijkstra's shortest-path algorithm ----

  /// Finds the shortest (lowest-cost) path from [startId] to [endId]
  /// using Dijkstra's algorithm with a priority queue.
  ///
  /// Edge cost is defined as `1 / weight` so that *stronger*
  /// relationships (higher weight) produce *shorter* paths.
  ///
  /// Returns the ordered list of contact IDs forming the path,
  /// or an empty list if no path exists.
  List<String> dijkstra(String startId, String endId) {
    if (!_nodes.containsKey(startId) || !_nodes.containsKey(endId)) {
      return [];
    }
    if (startId == endId) return [startId];

    // Distance table — shortest known cost to reach each node.
    final dist = <String, double>{};
    // Previous-node table for path reconstruction.
    final prev = <String, String?>{};
    // Visited set.
    final visited = <String>{};

    // Initialise all distances to infinity.
    for (final id in _nodes.keys) {
      dist[id] = double.infinity;
      prev[id] = null;
    }
    dist[startId] = 0.0;

    // Min-priority queue of (cost, nodeId).
    // Using a simple list-scan for clarity; for large graphs a binary
    // heap would be preferable but this is sufficient for the number
    // of contacts a typical user manages.
    while (true) {
      // Pick the unvisited node with the smallest distance.
      String? currentId;
      double currentDist = double.infinity;
      for (final id in dist.keys) {
        if (!visited.contains(id) && dist[id]! < currentDist) {
          currentDist = dist[id]!;
          currentId = id;
        }
      }

      if (currentId == null) break; // All remaining nodes unreachable.
      if (currentId == endId) break; // Found the target.

      visited.add(currentId);

      // Relax edges.
      final neighbours = _nodes[currentId]?.edges ?? {};
      for (final entry in neighbours.entries) {
        final neighbourId = entry.key;
        if (visited.contains(neighbourId)) continue;

        // Cost = inverse of weight (stronger link → lower cost).
        final edgeCost = 1.0 / entry.value;
        final newDist = currentDist + edgeCost;

        if (newDist < dist[neighbourId]!) {
          dist[neighbourId] = newDist;
          prev[neighbourId] = currentId;
        }
      }
    }

    // Reconstruct the path from endId back to startId.
    if (dist[endId] == double.infinity) return []; // No path exists.

    final path = <String>[];
    String? step = endId;
    while (step != null) {
      path.add(step);
      step = prev[step];
    }
    return path.reversed.toList();
  }

  /// Returns the total cost (sum of inverse-weights) of a path.
  double pathCost(List<String> path) {
    if (path.length < 2) return 0.0;
    double cost = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      final weight = _nodes[path[i]]?.edges[path[i + 1]] ?? 0.0;
      cost += (weight > 0 ? 1.0 / weight : double.infinity);
    }
    return cost;
  }

  // ---- Analytics helpers ----

  /// Average degree across all nodes.
  double get averageDegree {
    if (_nodes.isEmpty) return 0.0;
    int totalDegree = 0;
    for (final node in _nodes.values) {
      totalDegree += node.degree;
    }
    return totalDegree / _nodes.length;
  }

  /// Returns the node(s) with the highest degree (most connections).
  List<GraphNode> getMostConnectedContacts({int limit = 5}) {
    final sorted = _nodes.values.toList()
      ..sort((a, b) => b.degree.compareTo(a.degree));
    return sorted.take(limit).toList();
  }

  /// Summary statistics suitable for persisting to Firestore.
  Map<String, dynamic> toAnalyticsMap() {
    final components = getConnectedComponents();
    return {
      'node_count': nodeCount,
      'edge_count': edgeCount,
      'component_count': components.length,
      'average_degree': double.parse(averageDegree.toStringAsFixed(2)),
      'largest_component_size':
          components.isEmpty ? 0 : components.map((c) => c.length).reduce((a, b) => a > b ? a : b),
      'most_connected': getMostConnectedContacts(limit: 3)
          .map((n) => {'name': n.contactName, 'degree': n.degree})
          .toList(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // ---- Firestore integration ----

  /// Builds the contact graph from the user's Contact Directories.
  ///
  /// Algorithm:
  ///   1. Fetch all contacts for the current user.
  ///   2. Create a node per contact.
  ///   3. Build an inverted index: list_name → [contactIds].
  ///   4. For every list, create edges between all contacts that
  ///      share it.  Duplicate edges increment weight (+=1).
  static Future<ContactGraph> buildFromFirestore(String userId) async {
    final graph = ContactGraph();

    final snapshot = await FirebaseFirestore.instance
        .collection('Contact Directories')
        .where('user_id', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) return graph;

    // Inverted index: listName → set of contactDoc IDs.
    final listToContacts = <String, Set<String>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final contactId = doc.id;
      final contactName = (data['contact_name'] ?? '') as String;
      final phoneNumber = (data['contact_phone_number'] ?? '') as String;

      graph.addNode(GraphNode(
        contactId: contactId,
        contactName: contactName,
        phoneNumber: phoneNumber,
      ));

      // Extract list names from the new list_memberships map,
      // falling back to the legacy flat lists array.
      final memberships = data['list_memberships'];
      List<String> contactLists = [];

      if (memberships is Map) {
        contactLists = memberships.keys.cast<String>().toList();
      } else {
        final legacyLists = data['lists'];
        if (legacyLists is List) {
          contactLists = legacyLists.cast<String>();
        }
      }

      for (final listName in contactLists) {
        listToContacts.putIfAbsent(listName, () => {}).add(contactId);
      }
    }

    // Create edges between every pair of contacts that share a list.
    for (final contactIds in listToContacts.values) {
      final ids = contactIds.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final existingWeight =
              graph._nodes[ids[i]]?.edges[ids[j]] ?? 0.0;
          graph.addEdge(ids[i], ids[j], existingWeight + 1.0);
        }
      }
    }

    return graph;
  }

  /// Persists graph analytics to the user's settings document.
  Future<void> saveAnalyticsToFirestore(String userId) async {
    await FirebaseFirestore.instance
        .collection('user_settings')
        .doc(userId)
        .set(
      {'graph_analytics': toAnalyticsMap()},
      SetOptions(merge: true),
    );
  }
}
