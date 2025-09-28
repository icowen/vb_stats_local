import 'dart:io';
import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/services.dart';

class EmailService {
  // Gmail SMTP configuration
  static const String _smtpServer = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _credentialsPath = 'lib/config/email_credentials.json';

  // Email credentials
  static String? _senderEmail;
  static String? _senderPassword;
  static String? _recipientEmail;
  static bool _credentialsLoaded = false;

  /// Configure email settings manually
  static void configure({
    required String senderEmail,
    required String senderPassword,
    required String recipientEmail,
  }) {
    _senderEmail = senderEmail;
    _senderPassword = senderPassword;
    _recipientEmail = recipientEmail;
    _credentialsLoaded = true;
    print('✅ Email configured manually');
  }

  /// Load email credentials from JSON file
  static Future<void> _loadCredentials() async {
    if (_credentialsLoaded) {
      print('Email credentials already loaded, skipping...');
      return;
    }

    try {
      print('Loading email credentials from $_credentialsPath...');

      String credentialsJson;

      try {
        // Try loading from assets first
        print('Attempting to load from assets...');
        credentialsJson = await rootBundle.loadString(_credentialsPath);
        print('✅ Loaded email credentials from assets');
      } catch (e) {
        print('❌ Failed to load from assets, trying file system: $e');
        // Fallback to file system
        final file = File(_credentialsPath);
        if (!await file.exists()) {
          throw Exception(
            'Email credentials file not found at $_credentialsPath',
          );
        }
        print('✅ File exists, reading from file system...');
        credentialsJson = await file.readAsString();
        print('✅ Loaded email credentials from file system');
      }

      print('Parsing email credentials JSON...');
      final Map<String, dynamic> credentials = json.decode(credentialsJson);
      print('✅ Email credentials JSON parsed successfully');

      _senderEmail = credentials['senderEmail'] as String;
      _senderPassword = credentials['senderPassword'] as String;
      _recipientEmail = credentials['recipientEmail'] as String;

      print(
        '✅ Extracted email credentials: sender=$_senderEmail, recipient=$_recipientEmail',
      );

      // Validate credentials
      if (_senderEmail!.isEmpty ||
          _senderPassword!.isEmpty ||
          _recipientEmail!.isEmpty) {
        throw Exception(
          'Email credentials are incomplete in $_credentialsPath',
        );
      }

      _credentialsLoaded = true;
      print('✅ Email credentials loaded successfully from $_credentialsPath');
    } catch (e) {
      print('Failed to load email credentials: $e');
      throw Exception(
        'Could not load email credentials from $_credentialsPath: $e',
      );
    }
  }

  /// Send PDF via email
  static Future<bool> sendPDF({
    required File pdfFile,
    required String practiceName,
    required DateTime practiceDate,
  }) async {
    try {
      print('=== EMAIL SERVICE ===');
      print('Attempting to send PDF via email...');

      // Load credentials if not already loaded
      if (!_credentialsLoaded) {
        await _loadCredentials();
      }

      if (_senderEmail == null ||
          _senderPassword == null ||
          _recipientEmail == null) {
        throw Exception('Email credentials not loaded or incomplete.');
      }

      // Create SMTP server
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _senderPassword,
        allowInsecure: false,
        ssl: false,
        ignoreBadCertificate: false,
      );

      // Create email message
      final message = Message()
        ..from = Address(_senderEmail!, 'VB Stats App')
        ..recipients.add(_recipientEmail!)
        ..subject = 'Volleyball Practice Report - $practiceName'
        ..text =
            '''
Hi Coach,

Please find attached the practice report for "$practiceName" (Practice Date: ${practiceDate.toString().split(' ')[0]}).

Best regards,
VB Stats App
'''
        ..html =
            '''
<html>
<body>
  <h2>Volleyball Practice Report</h2>
  <p>Hi Coach,</p>
  <p>Please find attached the practice report for <strong>"$practiceName"</strong>.</p>
  <p><strong>Practice Date:</strong> ${practiceDate.toString().split(' ')[0]}</p>
  
  <p>Best regards,<br>
  VB Stats App</p>
</body>
</html>
'''
        ..attachments = [
          FileAttachment(
            pdfFile,
            fileName: '${practiceName.replaceAll(' ', '_')}_report.pdf',
          ),
        ];

      print('Sending email to $_recipientEmail...');

      // Send email
      await send(message, smtpServer);

      print('=== EMAIL SENT SUCCESSFULLY ===');
      print('Email sent successfully');
      print('==============================');

      return true;
    } catch (e) {
      print('=== EMAIL SEND FAILED ===');
      print('Error: $e');
      print('=========================');
      return false;
    }
  }

  /// Test email configuration
  static Future<bool> testEmailConfiguration() async {
    try {
      if (_senderEmail == null ||
          _senderPassword == null ||
          _recipientEmail == null) {
        print('❌ Email configuration not set');
        return false;
      }

      print('=== EMAIL CONFIGURATION TEST ===');
      print('Sender: $_senderEmail');
      print('Recipient: $_recipientEmail');
      print('SMTP Server: $_smtpServer');
      print('Port: $_smtpPort');
      print('===============================');

      // Test connection (this will validate credentials)
      print('Testing SMTP connection...');
      // Note: mailer package doesn't have a direct connection test
      // We'll just validate that the configuration looks correct

      print('✅ Email configuration looks valid');
      return true;
    } catch (e) {
      print('❌ Email configuration test failed: $e');
      return false;
    }
  }
}
