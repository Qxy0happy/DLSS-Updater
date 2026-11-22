// This is a generated file - do not edit.
//
// Generated from dlss/v1/library.proto.

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

@$core.Deprecated('Use listGamesRequestDescriptor instead')
const ListGamesRequest$json = {
  '1': 'ListGamesRequest',
};

/// Descriptor for `ListGamesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGamesRequestDescriptor =
    $convert.base64Decode('ChBMaXN0R2FtZXNSZXF1ZXN0');

@$core.Deprecated('Use listGamesResponseDescriptor instead')
const ListGamesResponse$json = {
  '1': 'ListGamesResponse',
  '2': [
    {
      '1': 'games',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dlss.v1.Game',
      '10': 'games'
    },
  ],
};

/// Descriptor for `ListGamesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGamesResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0R2FtZXNSZXNwb25zZRIjCgVnYW1lcxgBIAMoCzINLmRsc3MudjEuR2FtZVIFZ2FtZX'
    'M=');

@$core.Deprecated('Use getGameRequestDescriptor instead')
const GetGameRequest$json = {
  '1': 'GetGameRequest',
  '2': [
    {'1': 'game_id', '3': 1, '4': 1, '5': 9, '10': 'gameId'},
  ],
};

/// Descriptor for `GetGameRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGameRequestDescriptor = $convert
    .base64Decode('Cg5HZXRHYW1lUmVxdWVzdBIXCgdnYW1lX2lkGAEgASgJUgZnYW1lSWQ=');
