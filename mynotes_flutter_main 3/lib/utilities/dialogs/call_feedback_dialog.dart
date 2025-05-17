import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class CallFeedbackDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    bool callAnswered = false;
    bool voicemailLeft = false;
    int starRating = 0;

    return AlertDialog(
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Call with $contactName',
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
                  starRating = rating.toInt();
                },
              ),
              SizedBox(height: 8),
              Text('Call duration: ${callDuration.inSeconds} seconds'),
            ],
          );
        },
      ),
    );
  }
}
