// This is a generated file - do not edit.
//
// Generated from dlss/v1/scan.proto.

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

@$core.Deprecated('Use startScanRequestDescriptor instead')
const StartScanRequest$json = {
  '1': 'StartScanRequest',
  '2': [
    {'1': 'steam_root', '3': 1, '4': 1, '5': 9, '10': 'steamRoot'},
    {
      '1': 'sources',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.dlss.v1.ScanSource',
      '10': 'sources'
    },
  ],
};

/// Descriptor for `StartScanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startScanRequestDescriptor = $convert.base64Decode(
    'ChBTdGFydFNjYW5SZXF1ZXN0Eh0KCnN0ZWFtX3Jvb3QYASABKAlSCXN0ZWFtUm9vdBItCgdzb3'
    'VyY2VzGAIgAygLMhMuZGxzcy52MS5TY2FuU291cmNlUgdzb3VyY2Vz');

@$core.Deprecated('Use scanSourceDescriptor instead')
const ScanSource$json = {
  '1': 'ScanSource',
  '2': [
    {
      '1': 'steam',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.SteamSource',
      '9': 0,
      '10': 'steam'
    },
    {
      '1': 'custom_folder',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.CustomFolderSource',
      '9': 0,
      '10': 'customFolder'
    },
    {
      '1': 'heroic',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.HeroicSource',
      '9': 0,
      '10': 'heroic'
    },
    {
      '1': 'lutris',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.LutrisSource',
      '9': 0,
      '10': 'lutris'
    },
  ],
  '8': [
    {'1': 'source'},
  ],
};

/// Descriptor for `ScanSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanSourceDescriptor = $convert.base64Decode(
    'CgpTY2FuU291cmNlEiwKBXN0ZWFtGAEgASgLMhQuZGxzcy52MS5TdGVhbVNvdXJjZUgAUgVzdG'
    'VhbRJCCg1jdXN0b21fZm9sZGVyGAIgASgLMhsuZGxzcy52MS5DdXN0b21Gb2xkZXJTb3VyY2VI'
    'AFIMY3VzdG9tRm9sZGVyEi8KBmhlcm9pYxgDIAEoCzIVLmRsc3MudjEuSGVyb2ljU291cmNlSA'
    'BSBmhlcm9pYxIvCgZsdXRyaXMYBCABKAsyFS5kbHNzLnYxLkx1dHJpc1NvdXJjZUgAUgZsdXRy'
    'aXNCCAoGc291cmNl');

@$core.Deprecated('Use steamSourceDescriptor instead')
const SteamSource$json = {
  '1': 'SteamSource',
  '2': [
    {'1': 'root', '3': 1, '4': 1, '5': 9, '10': 'root'},
  ],
};

/// Descriptor for `SteamSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List steamSourceDescriptor =
    $convert.base64Decode('CgtTdGVhbVNvdXJjZRISCgRyb290GAEgASgJUgRyb290');

@$core.Deprecated('Use customFolderSourceDescriptor instead')
const CustomFolderSource$json = {
  '1': 'CustomFolderSource',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `CustomFolderSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List customFolderSourceDescriptor = $convert
    .base64Decode('ChJDdXN0b21Gb2xkZXJTb3VyY2USEgoEcGF0aBgBIAEoCVIEcGF0aA==');

@$core.Deprecated('Use heroicSourceDescriptor instead')
const HeroicSource$json = {
  '1': 'HeroicSource',
};

/// Descriptor for `HeroicSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heroicSourceDescriptor =
    $convert.base64Decode('CgxIZXJvaWNTb3VyY2U=');

@$core.Deprecated('Use lutrisSourceDescriptor instead')
const LutrisSource$json = {
  '1': 'LutrisSource',
};

/// Descriptor for `LutrisSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lutrisSourceDescriptor =
    $convert.base64Decode('CgxMdXRyaXNTb3VyY2U=');

@$core.Deprecated('Use scanEventDescriptor instead')
const ScanEvent$json = {
  '1': 'ScanEvent',
  '2': [
    {
      '1': 'started',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.ScanStarted',
      '9': 0,
      '10': 'started'
    },
    {
      '1': 'library_progress',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.ScanLibraryProgress',
      '9': 0,
      '10': 'libraryProgress'
    },
    {
      '1': 'game_found',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.Game',
      '9': 0,
      '10': 'gameFound'
    },
    {
      '1': 'finished',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.ScanFinished',
      '9': 0,
      '10': 'finished'
    },
    {
      '1': 'failed',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.ScanFailed',
      '9': 0,
      '10': 'failed'
    },
    {
      '1': 'warning',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.ScanWarning',
      '9': 0,
      '10': 'warning'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `ScanEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanEventDescriptor = $convert.base64Decode(
    'CglTY2FuRXZlbnQSMAoHc3RhcnRlZBgBIAEoCzIULmRsc3MudjEuU2NhblN0YXJ0ZWRIAFIHc3'
    'RhcnRlZBJJChBsaWJyYXJ5X3Byb2dyZXNzGAIgASgLMhwuZGxzcy52MS5TY2FuTGlicmFyeVBy'
    'b2dyZXNzSABSD2xpYnJhcnlQcm9ncmVzcxIuCgpnYW1lX2ZvdW5kGAMgASgLMg0uZGxzcy52MS'
    '5HYW1lSABSCWdhbWVGb3VuZBIzCghmaW5pc2hlZBgEIAEoCzIVLmRsc3MudjEuU2NhbkZpbmlz'
    'aGVkSABSCGZpbmlzaGVkEi0KBmZhaWxlZBgFIAEoCzITLmRsc3MudjEuU2NhbkZhaWxlZEgAUg'
    'ZmYWlsZWQSMAoHd2FybmluZxgGIAEoCzIULmRsc3MudjEuU2Nhbldhcm5pbmdIAFIHd2Fybmlu'
    'Z0IHCgVldmVudA==');

@$core.Deprecated('Use scanStartedDescriptor instead')
const ScanStarted$json = {
  '1': 'ScanStarted',
  '2': [
    {'1': 'steam_root', '3': 1, '4': 1, '5': 9, '10': 'steamRoot'},
    {
      '1': 'started_at',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'startedAt'
    },
  ],
};

/// Descriptor for `ScanStarted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanStartedDescriptor = $convert.base64Decode(
    'CgtTY2FuU3RhcnRlZBIdCgpzdGVhbV9yb290GAEgASgJUglzdGVhbVJvb3QSOQoKc3RhcnRlZF'
    '9hdBgCIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXN0YXJ0ZWRBdA==');

@$core.Deprecated('Use scanLibraryProgressDescriptor instead')
const ScanLibraryProgress$json = {
  '1': 'ScanLibraryProgress',
  '2': [
    {'1': 'library_path', '3': 1, '4': 1, '5': 9, '10': 'libraryPath'},
    {'1': 'library_index', '3': 2, '4': 1, '5': 5, '10': 'libraryIndex'},
    {'1': 'library_count', '3': 3, '4': 1, '5': 5, '10': 'libraryCount'},
    {'1': 'current_game', '3': 4, '4': 1, '5': 9, '10': 'currentGame'},
    {'1': 'games_found', '3': 5, '4': 1, '5': 5, '10': 'gamesFound'},
    {'1': 'dlls_found', '3': 6, '4': 1, '5': 5, '10': 'dllsFound'},
  ],
};

/// Descriptor for `ScanLibraryProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanLibraryProgressDescriptor = $convert.base64Decode(
    'ChNTY2FuTGlicmFyeVByb2dyZXNzEiEKDGxpYnJhcnlfcGF0aBgBIAEoCVILbGlicmFyeVBhdG'
    'gSIwoNbGlicmFyeV9pbmRleBgCIAEoBVIMbGlicmFyeUluZGV4EiMKDWxpYnJhcnlfY291bnQY'
    'AyABKAVSDGxpYnJhcnlDb3VudBIhCgxjdXJyZW50X2dhbWUYBCABKAlSC2N1cnJlbnRHYW1lEh'
    '8KC2dhbWVzX2ZvdW5kGAUgASgFUgpnYW1lc0ZvdW5kEh0KCmRsbHNfZm91bmQYBiABKAVSCWRs'
    'bHNGb3VuZA==');

@$core.Deprecated('Use scanWarningDescriptor instead')
const ScanWarning$json = {
  '1': 'ScanWarning',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ScanWarning`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanWarningDescriptor = $convert.base64Decode(
    'CgtTY2FuV2FybmluZxISCgRwYXRoGAEgASgJUgRwYXRoEhgKB21lc3NhZ2UYAiABKAlSB21lc3'
    'NhZ2U=');

@$core.Deprecated('Use scanFinishedDescriptor instead')
const ScanFinished$json = {
  '1': 'ScanFinished',
  '2': [
    {'1': 'game_count', '3': 1, '4': 1, '5': 5, '10': 'gameCount'},
    {'1': 'dll_count', '3': 2, '4': 1, '5': 5, '10': 'dllCount'},
    {'1': 'cancelled', '3': 3, '4': 1, '5': 8, '10': 'cancelled'},
    {'1': 'duration_ms', '3': 4, '4': 1, '5': 3, '10': 'durationMs'},
  ],
};

/// Descriptor for `ScanFinished`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanFinishedDescriptor = $convert.base64Decode(
    'CgxTY2FuRmluaXNoZWQSHQoKZ2FtZV9jb3VudBgBIAEoBVIJZ2FtZUNvdW50EhsKCWRsbF9jb3'
    'VudBgCIAEoBVIIZGxsQ291bnQSHAoJY2FuY2VsbGVkGAMgASgIUgljYW5jZWxsZWQSHwoLZHVy'
    'YXRpb25fbXMYBCABKANSCmR1cmF0aW9uTXM=');

@$core.Deprecated('Use scanFailedDescriptor instead')
const ScanFailed$json = {
  '1': 'ScanFailed',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ScanFailed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanFailedDescriptor = $convert.base64Decode(
    'CgpTY2FuRmFpbGVkEhYKBnJlYXNvbhgBIAEoCVIGcmVhc29uEhgKB21lc3NhZ2UYAiABKAlSB2'
    '1lc3NhZ2U=');
