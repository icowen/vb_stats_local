import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:aws_client/s3_2006_03_01.dart';
import 'package:path_provider/path_provider.dart';

class S3Service {
  static const String _bucketName = 'coach-ian-stats';
  static const String _credentialsPath = 'lib/config/aws_credentials.json';

  static S3? _s3Client;
  static Map<String, String>? _credentials;
  static bool _credentialsLoaded = false;

  /// Reset credentials state (useful for debugging)
  static void resetCredentials() {
    print('🔄 Resetting S3 credentials state...');
    _credentialsLoaded = false;
    _credentials = null;
    _s3Client = null;
    print('✅ Credentials state reset');
  }

  /// Initialize S3 client if credentials are available but client is missing
  static void _initializeS3Client() {
    if (_credentials != null && _s3Client == null) {
      print('🔧 Initializing S3 client from stored credentials...');

      final String accessKeyId = _credentials!['accessKeyId']!;
      final String secretAccessKey = _credentials!['secretAccessKey']!;
      final String region = _credentials!['region']!;

      _s3Client = S3(
        region: region,
        credentials: AwsClientCredentials(
          accessKey: accessKeyId,
          secretKey: secretAccessKey,
        ),
      );

      print('✅ S3 client initialized from stored credentials');
      print('Region: $region');
      print('Access Key: ${accessKeyId.substring(0, 8)}...');
    } else if (_credentials == null) {
      print('❌ Cannot initialize S3 client - no credentials available');
    } else {
      print('ℹ️  S3 client already initialized');
    }
  }

  /// Load AWS credentials from config file
  static Future<void> _loadCredentials() async {
    if (_credentialsLoaded && _credentials != null && _s3Client != null) {
      print('Credentials already loaded and valid, skipping...');
      print('_credentialsLoaded: $_credentialsLoaded');
      print('_credentials: $_credentials');
      print('_s3Client: $_s3Client');
      return;
    }

    if (_credentialsLoaded) {
      print(
        '⚠️  _credentialsLoaded is true but credentials are null - resetting...',
      );
      _credentialsLoaded = false;
      _credentials = null;
      _s3Client = null;
    }

    try {
      print('Loading AWS credentials from $_credentialsPath...');

      String credentialsJson;

      try {
        // Try loading from assets first
        print('Attempting to load from assets...');
        credentialsJson = await rootBundle.loadString(_credentialsPath);
        print('✅ Loaded credentials from assets');
      } catch (e) {
        print('❌ Failed to load from assets, trying file system: $e');
        // Fallback to file system
        final file = File(_credentialsPath);
        if (!await file.exists()) {
          throw Exception('Credentials file not found at $_credentialsPath');
        }
        print('✅ File exists, reading from file system...');
        credentialsJson = await file.readAsString();
        print('✅ Loaded credentials from file system');
      }

      print('Parsing JSON credentials...');
      final Map<String, dynamic> credentials = json.decode(credentialsJson);
      print('✅ JSON parsed successfully');

      final String accessKeyId = credentials['accessKeyId'] as String;
      final String secretAccessKey = credentials['secretAccessKey'] as String;
      final String region = credentials['region'] as String;
      print(
        '✅ Extracted credentials: region=$region, accessKey=${accessKeyId.substring(0, 8)}...',
      );

      // Validate credentials
      if (accessKeyId.isEmpty || secretAccessKey.isEmpty || region.isEmpty) {
        throw Exception('AWS credentials are incomplete in $_credentialsPath');
      }

      // Store credentials
      _credentials = {
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        'region': region,
      };

      // Initialize S3 client with credentials from JSON file
      print('Initializing S3 client...');
      _s3Client = S3(
        region: region,
        credentials: AwsClientCredentials(
          accessKey: accessKeyId,
          secretKey: secretAccessKey,
        ),
      );
      print('✅ S3 client initialized');

      _credentialsLoaded = true;
      print('✅ AWS credentials loaded successfully from $_credentialsPath');
      print('Region: $region');
      print('Access Key: ${accessKeyId.substring(0, 8)}...');
      print('_credentialsLoaded: $_credentialsLoaded');
      print('_credentials: $_credentials');
      print('_s3Client: $_s3Client');
    } catch (e) {
      print('Failed to load AWS credentials: $e');
      if (e.toString().contains('not found')) {
        throw Exception(
          'AWS credentials file not found at $_credentialsPath. Please ensure the file exists.',
        );
      } else if (e.toString().contains('Invalid argument')) {
        throw Exception(
          'Invalid JSON in credentials file $_credentialsPath. Please check the file format.',
        );
      } else {
        throw Exception(
          'Could not load AWS credentials from $_credentialsPath: $e',
        );
      }
    }
  }

  /// Upload a PDF file to S3
  static Future<String> uploadPDF({
    required File pdfFile,
    required String practiceName,
    required DateTime generationTime,
  }) async {
    try {
      print('=== S3 UPLOAD START ===');
      print('uploadPDF called with practice: $practiceName');

      // Load credentials if not already loaded
      print('About to call _loadCredentials()...');
      print('Current state before loading:');
      print('  _credentialsLoaded: $_credentialsLoaded');
      print('  _credentials: $_credentials');
      print('  _s3Client: $_s3Client');

      await _loadCredentials();
      print('_loadCredentials() completed');

      print('Current state after loading:');
      print('  _credentialsLoaded: $_credentialsLoaded');
      print('  _credentials: $_credentials');
      print('  _s3Client: $_s3Client');

      // Check if we have credentials but no S3 client
      if (_credentials != null && _s3Client == null) {
        print('Credentials available but S3 client missing - initializing...');
        _initializeS3Client();
      }

      if (_s3Client == null || _credentials == null) {
        throw Exception('S3 client or credentials not initialized');
      }

      // Get region from credentials
      final region = _credentials!['region'];
      if (region == null || region.isEmpty) {
        throw Exception('Region not found in credentials');
      }

      // Generate S3 key with practice/analysis/ prefix
      final timestamp = generationTime.toIso8601String().replaceAll(':', '-');
      final sanitizedPracticeName = practiceName
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s-]'), '') // Remove special chars
          .replaceAll(' ', '_')
          .toLowerCase();

      final s3Key =
          'practice/analysis/${sanitizedPracticeName}_${timestamp}.pdf';

      // Read file bytes
      final fileBytes = await pdfFile.readAsBytes();

      // Upload to S3
      print('=== S3 UPLOAD DEBUG ===');
      print('Bucket: $_bucketName');
      print('Key: $s3Key');
      print('File size: ${fileBytes.length} bytes');
      print('Region: $region');
      print('Attempting upload...');

      if (_s3Client == null) {
        throw Exception('S3 client is null during upload');
      }

      await _s3Client!.putObject(
        bucket: _bucketName,
        key: s3Key,
        body: fileBytes,
      );

      print('Upload completed successfully!');

      // Get region for URL construction (already have it from above)

      // Return S3 URL
      final s3Url = 'https://$_bucketName.s3.$region.amazonaws.com/$s3Key';

      print('=== S3 UPLOAD SUCCESS ===');
      print('S3 Bucket: $_bucketName');
      print('S3 Key: $s3Key');
      print('S3 URL: $s3Url');
      print('File Size: ${fileBytes.length} bytes');
      print('========================');

      // Close the S3 client
      if (_s3Client != null) {
        _s3Client!.close();
      }

      return s3Url;
    } catch (e) {
      print('=== S3 UPLOAD ERROR ===');
      print('Error: $e');
      print('=======================');
      rethrow;
    }
  }

  /// Test S3 connection with detailed logging
  static Future<bool> testConnection() async {
    try {
      await _loadCredentials();

      // Check if we have credentials but no S3 client
      if (_credentials != null && _s3Client == null) {
        print('Credentials available but S3 client missing - initializing...');
        _initializeS3Client();
      }

      if (_s3Client == null) {
        print('S3 connection test failed: S3 client not initialized');
        return false;
      }

      print('=== S3 CONNECTION TEST ===');
      print('Testing connection to bucket: $_bucketName');
      if (_credentials != null) {
        print('Region: ${_credentials!['region']}');
        print('Access Key: ${_credentials!['accessKeyId']}');
      }
      print('Attempting headBucket...');

      if (_s3Client == null) {
        print('S3 client is null during connection test');
        return false;
      }

      await _s3Client!.headBucket(bucket: _bucketName);
      _s3Client!.close();

      print('S3 connection test successful!');
      print('==============================');
      return true;
    } catch (e) {
      print('S3 connection test failed: $e');
      return false;
    }
  }

  /// Test if credentials are loaded correctly
  static Future<bool> testCredentials() async {
    try {
      print('=== CREDENTIALS TEST DEBUG ===');
      print('_credentialsLoaded: $_credentialsLoaded');
      print('_credentials: $_credentials');
      print('_s3Client: $_s3Client');

      // Reset credentials to force fresh load
      resetCredentials();

      await _loadCredentials();

      print('After _loadCredentials():');
      print('_credentialsLoaded: $_credentialsLoaded');
      print('_credentials: $_credentials');
      print('_s3Client: $_s3Client');

      if (_credentials != null && _s3Client != null) {
        print('✅ Credentials loaded successfully');
        print('Region: ${_credentials!['region']}');
        print(
          'Access Key: ${_credentials!['accessKeyId']?.substring(0, 8)}...',
        );
        return true;
      } else {
        print('❌ Credentials not loaded');
        print('_credentials is null: ${_credentials == null}');
        print('_s3Client is null: ${_s3Client == null}');
        return false;
      }
    } catch (e) {
      print('❌ Credentials test failed: $e');
      return false;
    }
  }

  /// Simple test method that can be called from your app
  static Future<void> testS3Setup() async {
    print('=== S3 SETUP TEST ===');
    try {
      // Test credentials first
      final credsOk = await testCredentials();
      if (!credsOk) {
        print('❌ Credentials test FAILED - stopping here');
        return;
      }

      // Test connection
      final success = await testConnection();
      if (success) {
        print('✅ S3 connection test PASSED');
      } else {
        print('❌ S3 connection test FAILED');
      }
    } catch (e) {
      print('❌ S3 setup test ERROR: $e');
    }
    print('=====================');
  }

  /// Quick test to see if uploadPDF method is working
  static Future<void> testUploadPDFMethod() async {
    print('=== TESTING UPLOAD PDF METHOD ===');
    try {
      // Create a dummy file for testing
      final tempDir = await getTemporaryDirectory();
      final testFile = File('${tempDir.path}/test.pdf');
      await testFile.writeAsString('This is a test PDF content');

      print('Created test file: ${testFile.path}');

      // Try to call uploadPDF
      print('Calling uploadPDF method...');
      final result = await uploadPDF(
        pdfFile: testFile,
        practiceName: 'test-practice',
        generationTime: DateTime.now(),
      );

      print('✅ Upload PDF method completed successfully!');
      print('Result: $result');

      // Clean up test file
      await testFile.delete();
      print('Cleaned up test file');
    } catch (e) {
      print('❌ Upload PDF method test FAILED: $e');
    }
    print('================================');
  }
}
