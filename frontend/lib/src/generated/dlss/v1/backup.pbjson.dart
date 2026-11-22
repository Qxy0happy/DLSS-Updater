// This is a generated file - do not edit.
//
// Generated from dlss/v1/backup.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use listBackupsRequestDescriptor instead')
const ListBackupsRequest$json = {
  '1': 'ListBackupsRequest',
  '2': [
    {'1': 'game_id', '3': 1, '4': 1, '5': 9, '10': 'gameId'},
    {'1': 'include_inactive', '3': 2, '4': 1, '5': 8, '10': 'includeInactive'},
  ],
};

/// Descriptor for `ListBackupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBackupsRequestDescriptor = $convert.base64Decode(
    'ChJMaXN0QmFja3Vwc1JlcXVlc3QSFwoHZ2FtZV9pZBgBIAEoCVIGZ2FtZUlkEikKEGluY2x1ZG'
    'VfaW5hY3RpdmUYAiABKAhSD2luY2x1ZGVJbmFjdGl2ZQ==');

@$core.Deprecated('Use listBackupsResponseDescriptor instead')
const ListBackupsResponse$json = {
  '1': 'ListBackupsResponse',
  '2': [
    {
      '1': 'backups',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dlss.v1.BackupRecord',
      '10': 'backups'
    },
  ],
};

/// Descriptor for `ListBackupsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBackupsResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0QmFja3Vwc1Jlc3BvbnNlEi8KB2JhY2t1cHMYASADKAsyFS5kbHNzLnYxLkJhY2t1cF'
    'JlY29yZFIHYmFja3Vwcw==');

@$core.Deprecated('Use restoreBackupRequestDescriptor instead')
const RestoreBackupRequest$json = {
  '1': 'RestoreBackupRequest',
  '2': [
    {'1': 'backup_id', '3': 1, '4': 1, '5': 9, '10': 'backupId'},
  ],
};

/// Descriptor for `RestoreBackupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreBackupRequestDescriptor =
    $convert.base64Decode(
        'ChRSZXN0b3JlQmFja3VwUmVxdWVzdBIbCgliYWNrdXBfaWQYASABKAlSCGJhY2t1cElk');

@$core.Deprecated('Use restoreBackupResponseDescriptor instead')
const RestoreBackupResponse$json = {
  '1': 'RestoreBackupResponse',
  '2': [
    {'1': 'dll', '3': 1, '4': 1, '5': 11, '6': '.dlss.v1.GameDLL', '10': 'dll'},
    {
      '1': 'backup',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.BackupRecord',
      '10': 'backup'
    },
  ],
};

/// Descriptor for `RestoreBackupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreBackupResponseDescriptor = $convert.base64Decode(
    'ChVSZXN0b3JlQmFja3VwUmVzcG9uc2USIgoDZGxsGAEgASgLMhAuZGxzcy52MS5HYW1lRExMUg'
    'NkbGwSLQoGYmFja3VwGAIgASgLMhUuZGxzcy52MS5CYWNrdXBSZWNvcmRSBmJhY2t1cA==');

@$core.Deprecated('Use deleteBackupRequestDescriptor instead')
const DeleteBackupRequest$json = {
  '1': 'DeleteBackupRequest',
  '2': [
    {'1': 'backup_id', '3': 1, '4': 1, '5': 9, '10': 'backupId'},
  ],
};

/// Descriptor for `DeleteBackupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBackupRequestDescriptor =
    $convert.base64Decode(
        'ChNEZWxldGVCYWNrdXBSZXF1ZXN0EhsKCWJhY2t1cF9pZBgBIAEoCVIIYmFja3VwSWQ=');

@$core.Deprecated('Use deleteBackupResponseDescriptor instead')
const DeleteBackupResponse$json = {
  '1': 'DeleteBackupResponse',
};

/// Descriptor for `DeleteBackupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBackupResponseDescriptor =
    $convert.base64Decode('ChREZWxldGVCYWNrdXBSZXNwb25zZQ==');
