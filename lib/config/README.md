# AWS Credentials Configuration

This directory contains configuration files for AWS S3 integration.

## Setup Instructions

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Create Credentials File**
   - Copy `aws_credentials.json.example` to `aws_credentials.json`
   - Fill in your AWS credentials:
   ```json
   {
     "accessKeyId": "YOUR_ACTUAL_ACCESS_KEY_ID",
     "secretAccessKey": "YOUR_ACTUAL_SECRET_ACCESS_KEY", 
     "region": "us-east-1"
   }
   ```

3. **Security Notes**
   - The `aws_credentials.json` file is excluded from version control (see .gitignore)
   - Never commit actual credentials to the repository
   - The example file can be safely committed as it contains no real credentials

## File Structure
```
lib/config/
├── README.md (this file)
├── aws_credentials.json.example (template)
└── aws_credentials.json (your actual credentials - not in git)
```

## S3 Bucket Configuration
- **Bucket Name**: `coach-ian-stats`
- **Region**: Configurable in credentials file (default: `us-east-1`)
- **Upload Path**: `practice/analysis/`
- **File Naming**: `{practice_name}_{timestamp}.pdf`

## Testing
You can test the S3 connection using:
```dart
final success = await S3Service.testConnection();
print('S3 connection: ${success ? 'SUCCESS' : 'FAILED'}');
```
