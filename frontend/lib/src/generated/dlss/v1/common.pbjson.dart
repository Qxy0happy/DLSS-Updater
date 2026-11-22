// This is a generated file - do not edit.
//
// Generated from dlss/v1/common.proto.

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

@$core.Deprecated('Use gameDescriptor instead')
const Game$json = {
  '1': 'Game',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'app_id', '3': 2, '4': 1, '5': 13, '10': 'appId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'install_path', '3': 4, '4': 1, '5': 9, '10': 'installPath'},
    {'1': 'library_path', '3': 5, '4': 1, '5': 9, '10': 'libraryPath'},
    {
      '1': 'dlls',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.dlss.v1.GameDLL',
      '10': 'dlls'
    },
  ],
};

/// Descriptor for `Game`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gameDescriptor = $convert.base64Decode(
    'CgRHYW1lEg4KAmlkGAEgASgJUgJpZBIVCgZhcHBfaWQYAiABKA1SBWFwcElkEhIKBG5hbWUYAy'
    'ABKAlSBG5hbWUSIQoMaW5zdGFsbF9wYXRoGAQgASgJUgtpbnN0YWxsUGF0aBIhCgxsaWJyYXJ5'
    'X3BhdGgYBSABKAlSC2xpYnJhcnlQYXRoEiQKBGRsbHMYBiADKAsyEC5kbHNzLnYxLkdhbWVETE'
    'xSBGRsbHM=');

@$core.Deprecated('Use gameDLLDescriptor instead')
const GameDLL$json = {
  '1': 'GameDLL',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'game_id', '3': 2, '4': 1, '5': 9, '10': 'gameId'},
    {'1': 'dll_type', '3': 3, '4': 1, '5': 9, '10': 'dllType'},
    {'1': 'filename', '3': 4, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'path', '3': 5, '4': 1, '5': 9, '10': 'path'},
    {'1': 'current_version', '3': 6, '4': 1, '5': 9, '10': 'currentVersion'},
    {'1': 'source_version', '3': 7, '4': 1, '5': 9, '10': 'sourceVersion'},
    {'1': 'exists', '3': 8, '4': 1, '5': 8, '10': 'exists'},
    {
      '1': 'missing_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'missingAt'
    },
  ],
};

/// Descriptor for `GameDLL`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gameDLLDescriptor = $convert.base64Decode(
    'CgdHYW1lRExMEg4KAmlkGAEgASgJUgJpZBIXCgdnYW1lX2lkGAIgASgJUgZnYW1lSWQSGQoIZG'
    'xsX3R5cGUYAyABKAlSB2RsbFR5cGUSGgoIZmlsZW5hbWUYBCABKAlSCGZpbGVuYW1lEhIKBHBh'
    'dGgYBSABKAlSBHBhdGgSJwoPY3VycmVudF92ZXJzaW9uGAYgASgJUg5jdXJyZW50VmVyc2lvbh'
    'IlCg5zb3VyY2VfdmVyc2lvbhgHIAEoCVINc291cmNlVmVyc2lvbhIWCgZleGlzdHMYCCABKAhS'
    'BmV4aXN0cxI5CgptaXNzaW5nX2F0GAkgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcF'
    'IJbWlzc2luZ0F0');

@$core.Deprecated('Use backupRecordDescriptor instead')
const BackupRecord$json = {
  '1': 'BackupRecord',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'game_id', '3': 2, '4': 1, '5': 9, '10': 'gameId'},
    {'1': 'dll_id', '3': 3, '4': 1, '5': 9, '10': 'dllId'},
    {'1': 'game_name', '3': 4, '4': 1, '5': 9, '10': 'gameName'},
    {'1': 'dll_filename', '3': 5, '4': 1, '5': 9, '10': 'dllFilename'},
    {'1': 'dll_type', '3': 6, '4': 1, '5': 9, '10': 'dllType'},
    {'1': 'backup_path', '3': 7, '4': 1, '5': 9, '10': 'backupPath'},
    {'1': 'original_version', '3': 8, '4': 1, '5': 9, '10': 'originalVersion'},
    {'1': 'size_bytes', '3': 9, '4': 1, '5': 3, '10': 'sizeBytes'},
    {
      '1': 'created_at',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {'1': 'is_active', '3': 11, '4': 1, '5': 8, '10': 'isActive'},
    {
      '1': 'restored_at',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'restoredAt'
    },
    {'1': 'target_exists', '3': 13, '4': 1, '5': 8, '10': 'targetExists'},
  ],
};

/// Descriptor for `BackupRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupRecordDescriptor = $convert.base64Decode(
    'CgxCYWNrdXBSZWNvcmQSDgoCaWQYASABKAlSAmlkEhcKB2dhbWVfaWQYAiABKAlSBmdhbWVJZB'
    'IVCgZkbGxfaWQYAyABKAlSBWRsbElkEhsKCWdhbWVfbmFtZRgEIAEoCVIIZ2FtZU5hbWUSIQoM'
    'ZGxsX2ZpbGVuYW1lGAUgASgJUgtkbGxGaWxlbmFtZRIZCghkbGxfdHlwZRgGIAEoCVIHZGxsVH'
    'lwZRIfCgtiYWNrdXBfcGF0aBgHIAEoCVIKYmFja3VwUGF0aBIpChBvcmlnaW5hbF92ZXJzaW9u'
    'GAggASgJUg9vcmlnaW5hbFZlcnNpb24SHQoKc2l6ZV9ieXRlcxgJIAEoA1IJc2l6ZUJ5dGVzEj'
    'kKCmNyZWF0ZWRfYXQYCiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVk'
    'QXQSGwoJaXNfYWN0aXZlGAsgASgIUghpc0FjdGl2ZRI7CgtyZXN0b3JlZF9hdBgMIAEoCzIaLm'
    'dvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCnJlc3RvcmVkQXQSIwoNdGFyZ2V0X2V4aXN0cxgN'
    'IAEoCFIMdGFyZ2V0RXhpc3Rz');
