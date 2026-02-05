import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';

class CallFeedbackDialog extends StatefulWidget {
  final String contactName;
  final String phoneNumber;
  final String listName;
  final Function(int, String) onFeedbackSubmitted;
  final Duration callDuration;
  final Map<String, dynamic>? noteSummary; // NLP-generated summary of previous notes

  const CallFeedbackDialog({
    Key? key,
    required this.contactName,
    required this.phoneNumber,
    required this.listName,
    required this.onFeedbackSubmitted,
    required this.callDuration,
    this.noteSummary,
  }) : super(key: key);

  @override
  _CallFeedbackDialogState createState() => _CallFeedbackDialogState();
}

class _CallFeedbackDialogState extends State<CallFeedbackDialog> {
  int starRating = 0;
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    notesController = TextEditingController(text: 'Call initiated');
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Call Feedback', style: AppleTypography.withAppleFont(AppleTypography.headline6)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call with ${widget.contactName}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            
            // NLP-generated summary of previous notes
            if (widget.noteSummary != null && widget.noteSummary!['total_notes'] > 0) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize, size: 18, color: Colors.blue.shade700),
                        SizedBox(width: 6),
                        Text(
                          'Summary of Previous Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Keywords section
                    if ((widget.noteSummary!['keywords'] as List).isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (widget.noteSummary!['keywords'] as List<String>)
                            .map((keyword) => Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    keyword,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      SizedBox(height: 6),
                    ],
                    
                    // Common phrases section
                    if ((widget.noteSummary!['common_phrases'] as List).isNotEmpty) ...[
                      Text(
                        'Common: ${(widget.noteSummary!['common_phrases'] as List<String>).join(", ")}',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                    
                    // Stats
                    Text(
                      '${widget.noteSummary!['total_notes']} note${widget.noteSummary!['total_notes'] == 1 ? '' : 's'}, ${widget.noteSummary!['total_words']} words',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            Text('Call rating:'),
            SizedBox(height: 8),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  starRating = rating.toInt();
                });
              },
            ),
            SizedBox(height: 8),
            Text('Selected rating: ${starRating > 0 ? '$starRating/5' : 'Not rated'}'),
            SizedBox(height: 16),
            Text('Notes:'),
            SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add notes about this call...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onFeedbackSubmitted(starRating, notesController.text);
            Navigator.of(context).pop();
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
