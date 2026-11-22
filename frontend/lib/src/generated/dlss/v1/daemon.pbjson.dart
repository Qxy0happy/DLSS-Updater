// This is a generated file - do not edit.
//
// Generated from dlss/v1/daemon.proto.

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

@$core.Deprecated('Use getStatusRequestDescriptor instead')
const GetStatusRequest$json = {
  '1': 'GetStatusRequest',
};

/// Descriptor for `GetStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatusRequestDescriptor =
    $convert.base64Decode('ChBHZXRTdGF0dXNSZXF1ZXN0');

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'proto_version', '3': 1, '4': 1, '5': 9, '10': 'protoVersion'},
    {'1': 'app_version', '3': 2, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'pid', '3': 3, '4': 1, '5': 5, '10': 'pid'},
    {
      '1': 'start_time',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'startTime'
    },
    {'1': 'scan_running', '3': 5, '4': 1, '5': 8, '10': 'scanRunning'},
    {'1': 'update_running', '3': 6, '4': 1, '5': 8, '10': 'updateRunning'},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSIwoNcHJvdG9fdmVyc2lvbhgBIAEoCVIMcHJvdG9WZXJzaW9uEh8KC2FwcF92ZX'
    'JzaW9uGAIgASgJUgphcHBWZXJzaW9uEhAKA3BpZBgDIAEoBVIDcGlkEjkKCnN0YXJ0X3RpbWUY'
    'BCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUglzdGFydFRpbWUSIQoMc2Nhbl9ydW'
    '5uaW5nGAUgASgIUgtzY2FuUnVubmluZxIlCg51cGRhdGVfcnVubmluZxgGIAEoCFINdXBkYXRl'
    'UnVubmluZw==');

@$core.Deprecated('Use shutdownRequestDescriptor instead')
const ShutdownRequest$json = {
  '1': 'ShutdownRequest',
};

/// Descriptor for `ShutdownRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shutdownRequestDescriptor =
    $convert.base64Decode('Cg9TaHV0ZG93blJlcXVlc3Q=');

@$core.Deprecated('Use shutdownResponseDescriptor instead')
const ShutdownResponse$json = {
  '1': 'ShutdownResponse',
};

/// Descriptor for `ShutdownResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shutdownResponseDescriptor =
    $convert.base64Decode('ChBTaHV0ZG93blJlc3BvbnNl');
