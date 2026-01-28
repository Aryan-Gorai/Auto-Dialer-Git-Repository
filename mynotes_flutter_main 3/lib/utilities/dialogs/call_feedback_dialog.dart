import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';

class CallFeedbackDialog extends StatefulWidget {
  final String contactName;
  final String phoneNumber;
  final String listName;
  final Function(bool, bool, int) onFeedbackSubmitted;
  final Duration callDuration;

  const CallFeedbackDialog({
    Key? key,
    required this.contactName,
    required this.phoneNumber,
    required this.listName,
    required this.onFeedbackSubmitted,
    required this.callDuration,
  }) : super(key: key);

  @override
  _CallFeedbackDialogState createState() => _CallFeedbackDialogState();
}

class _CallFeedbackDialogState extends State<CallFeedbackDialog> {
  bool callAnswered = false;
  bool voicemailLeft = false;
  int starRating = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Call Feedback', style: AppleTypography.withAppleFont(AppleTypography.headline6)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Call with ${widget.contactName}',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Row(
            children: [
              Text('Call answered?'),
              SizedBox(width: 16),
              Switch(
                value: callAnswered,
                onChanged: (value) {
                  setState(() {
                    callAnswered = value;
                    if (callAnswered) {
                      voicemailLeft = false;
                    }
                  });
                },
              ),
              SizedBox(width: 8),
              Text(callAnswered ? 'Yes' : 'No'),
            ],
          ),
          if (!callAnswered) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Text('Voicemail left?'),
                SizedBox(width: 16),
                Switch(
                  value: voicemailLeft,
                  onChanged: (value) {
                    setState(() {
                      voicemailLeft = value;
                    });
                  },
                ),
                SizedBox(width: 8),
                Text(voicemailLeft ? 'Yes' : 'No'),
              ],
            ),
          ],
          SizedBox(height: 16),
          Text('Call rating:'),
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
          SizedBox(height: 8),
          Text('Call duration: ${widget.callDuration.inSeconds} seconds'),
        ],
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
            widget.onFeedbackSubmitted(callAnswered, voicemailLeft, starRating);
            Navigator.of(context).pop();
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
