// import 'individual_bar.dart';

// class BarData {


//   final double sunAmount;
//   final double monAmount;
//   final double tueAmount;
//   final double wedAmount;


//   BarData ({
//     required this.sunAmount, 
//     required this.monAmount, 
//     required this.tueAmount, 
//     required this.wedAmount,
//     });

//     List<IndividualBar> barData = [];

//     void initializeBarData() {
//       barData = [
//         IndividualBar(x: 0, y: sunAmount),
//         IndividualBar(x: 0, y: monAmount),
//         IndividualBar(x: 0, y: tueAmount),
//         IndividualBar(x: 0, y: wedAmount),

//       ];
//     }


// }

  
  
//   List<String> listNames = [];

// class Data extends StatefulWidget {
//   const Data({super.key});

//   @override
//   State<Data> createState() => _DataState();
// }

// class _DataState extends State<Data> {



//   Future<void> getListNames() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

//     List<String> names = snapshot.docs.map((DocumentSnapshot doc) {
//       return doc.get('list_name') as String;
//     }).toList();

//     setState(() {
//       listNames = names;
//       print(listNames);
//     });
//   }

//   List<int> listIndex = [];
//   Future<void> getListIndex() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

//     List<int> index = snapshot.docs.map((DocumentSnapshot doc) {
//       return doc.get('current_index') as int;
//     }).toList();

//     setState(() {
//       listIndex = index;
//       print(listIndex);
//     });
//   }


//   List<int> listTotalDocuments = [];
//   Future<void> getListTotalDocuments() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

//     List<int> totalDocuments = snapshot.docs.map((DocumentSnapshot doc) {
//       return doc.get('total_documents') as int;
//     }).toList();

//     setState(() {
//       listTotalDocuments = totalDocuments;
//       print(listTotalDocuments);
//     });
//   }




//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }