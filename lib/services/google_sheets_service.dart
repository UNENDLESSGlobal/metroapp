import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sheet_feedback_model.dart';

class GoogleSheetsService {
  static const String _webAppUrl =
      'https://script.google.com/macros/s/AKfycbzZUV1r4x3cRQnqH2Q1XC7tdM05uAVvSLA1Y3DVhjvkWkQUK-7ph9dfb3EdptGVM4xc4A/exec';

  Future<bool> submitFeedback(SheetFeedbackModel feedback) async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(feedback.toJson()),
      );

      // Google Apps Script redirects to a success page, so we need to check for redirect or 200
      if (response.statusCode == 302 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
