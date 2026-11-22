// This is a generated file - do not edit.
//
// Generated from dlss/v1/update.proto.

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

@$core.Deprecated('Use updateOutcomeDescriptor instead')
const UpdateOutcome$json = {
  '1': 'UpdateOutcome',
  '2': [
    {'1': 'UPDATE_OUTCOME_UNSPECIFIED', '2': 0},
    {'1': 'UPDATE_OUTCOME_UPDATED', '2': 1},
    {'1': 'UPDATE_OUTCOME_SKIPPED', '2': 2},
    {'1': 'UPDATE_OUTCOME_FAILED', '2': 3},
  ],
};

/// Descriptor for `UpdateOutcome`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List updateOutcomeDescriptor = $convert.base64Decode(
    'Cg1VcGRhdGVPdXRjb21lEh4KGlVQREFURV9PVVRDT01FX1VOU1BFQ0lGSUVEEAASGgoWVVBEQV'
    'RFX09VVENPTUVfVVBEQVRFRBABEhoKFlVQREFURV9PVVRDT01FX1NLSVBQRUQQAhIZChVVUERB'
    'VEVfT1VUQ09NRV9GQUlMRUQQAw==');

@$core.Deprecated('Use startUpdateRequestDescriptor instead')
const StartUpdateRequest$json = {
  '1': 'StartUpdateRequest',
  '2': [
    {'1': 'dll_ids', '3': 1, '4': 3, '5': 9, '10': 'dllIds'},
  ],
};

/// Descriptor for `StartUpdateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startUpdateRequestDescriptor =
    $convert.base64Decode(
        'ChJTdGFydFVwZGF0ZVJlcXVlc3QSFwoHZGxsX2lkcxgBIAMoCVIGZGxsSWRz');

@$core.Deprecated('Use updateEventDescriptor instead')
const UpdateEvent$json = {
  '1': 'UpdateEvent',
  '2': [
    {
      '1': 'started',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.UpdateStarted',
      '9': 0,
      '10': 'started'
    },
    {
      '1': 'item_started',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.UpdateItemStarted',
      '9': 0,
      '10': 'itemStarted'
    },
    {
      '1': 'item_finished',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.UpdateItemFinished',
      '9': 0,
      '10': 'itemFinished'
    },
    {
      '1': 'finished',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.UpdateFinished',
      '9': 0,
      '10': 'finished'
    },
    {
      '1': 'failed',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.dlss.v1.UpdateFailed',
      '9': 0,
      '10': 'failed'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `UpdateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateEventDescriptor = $convert.base64Decode(
    'CgtVcGRhdGVFdmVudBIyCgdzdGFydGVkGAEgASgLMhYuZGxzcy52MS5VcGRhdGVTdGFydGVkSA'
    'BSB3N0YXJ0ZWQSPwoMaXRlbV9zdGFydGVkGAIgASgLMhouZGxzcy52MS5VcGRhdGVJdGVtU3Rh'
    'cnRlZEgAUgtpdGVtU3RhcnRlZBJCCg1pdGVtX2ZpbmlzaGVkGAMgASgLMhsuZGxzcy52MS5VcG'
    'RhdGVJdGVtRmluaXNoZWRIAFIMaXRlbUZpbmlzaGVkEjUKCGZpbmlzaGVkGAQgASgLMhcuZGxz'
    'cy52MS5VcGRhdGVGaW5pc2hlZEgAUghmaW5pc2hlZBIvCgZmYWlsZWQYBSABKAsyFS5kbHNzLn'
    'YxLlVwZGF0ZUZhaWxlZEgAUgZmYWlsZWRCBwoFZXZlbnQ=');

@$core.Deprecated('Use updateStartedDescriptor instead')
const UpdateStarted$json = {
  '1': 'UpdateStarted',
  '2': [
    {'1': 'item_count', '3': 1, '4': 1, '5': 5, '10': 'itemCount'},
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

/// Descriptor for `UpdateStarted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateStartedDescriptor = $convert.base64Decode(
    'Cg1VcGRhdGVTdGFydGVkEh0KCml0ZW1fY291bnQYASABKAVSCWl0ZW1Db3VudBI5CgpzdGFydG'
    'VkX2F0GAIgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJc3RhcnRlZEF0');

@$core.Deprecated('Use updateItemStartedDescriptor instead')
const UpdateItemStarted$json = {
  '1': 'UpdateItemStarted',
  '2': [
    {'1': 'dll_id', '3': 1, '4': 1, '5': 9, '10': 'dllId'},
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'index', '3': 3, '4': 1, '5': 5, '10': 'index'},
    {'1': 'total', '3': 4, '4': 1, '5': 5, '10': 'total'},
  ],
};

/// Descriptor for `UpdateItemStarted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateItemStartedDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVJdGVtU3RhcnRlZBIVCgZkbGxfaWQYASABKAlSBWRsbElkEhoKCGZpbGVuYW1lGA'
    'IgASgJUghmaWxlbmFtZRIUCgVpbmRleBgDIAEoBVIFaW5kZXgSFAoFdG90YWwYBCABKAVSBXRv'
    'dGFs');

@$core.Deprecated('Use updateItemFinishedDescriptor instead')
const UpdateItemFinished$json = {
  '1': 'UpdateItemFinished',
  '2': [
    {'1': 'dll_id', '3': 1, '4': 1, '5': 9, '10': 'dllId'},
    {
      '1': 'outcome',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.dlss.v1.UpdateOutcome',
      '10': 'outcome'
    },
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'backup_id', '3': 4, '4': 1, '5': 9, '10': 'backupId'},
    {
      '1': 'resulting_version',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'resultingVersion'
    },
    {'1': 'duration_ms', '3': 6, '4': 1, '5': 3, '10': 'durationMs'},
  ],
};

/// Descriptor for `UpdateItemFinished`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateItemFinishedDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVJdGVtRmluaXNoZWQSFQoGZGxsX2lkGAEgASgJUgVkbGxJZBIwCgdvdXRjb21lGA'
    'IgASgOMhYuZGxzcy52MS5VcGRhdGVPdXRjb21lUgdvdXRjb21lEhYKBnJlYXNvbhgDIAEoCVIG'
    'cmVhc29uEhsKCWJhY2t1cF9pZBgEIAEoCVIIYmFja3VwSWQSKwoRcmVzdWx0aW5nX3ZlcnNpb2'
    '4YBSABKAlSEHJlc3VsdGluZ1ZlcnNpb24SHwoLZHVyYXRpb25fbXMYBiABKANSCmR1cmF0aW9u'
    'TXM=');

@$core.Deprecated('Use updateFinishedDescriptor instead')
const UpdateFinished$json = {
  '1': 'UpdateFinished',
  '2': [
    {'1': 'succeeded', '3': 1, '4': 1, '5': 5, '10': 'succeeded'},
    {'1': 'skipped', '3': 2, '4': 1, '5': 5, '10': 'skipped'},
    {'1': 'failed', '3': 3, '4': 1, '5': 5, '10': 'failed'},
    {'1': 'cancelled', '3': 4, '4': 1, '5': 8, '10': 'cancelled'},
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 3, '10': 'durationMs'},
  ],
};

/// Descriptor for `UpdateFinished`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateFinishedDescriptor = $convert.base64Decode(
    'Cg5VcGRhdGVGaW5pc2hlZBIcCglzdWNjZWVkZWQYASABKAVSCXN1Y2NlZWRlZBIYCgdza2lwcG'
    'VkGAIgASgFUgdza2lwcGVkEhYKBmZhaWxlZBgDIAEoBVIGZmFpbGVkEhwKCWNhbmNlbGxlZBgE'
    'IAEoCFIJY2FuY2VsbGVkEh8KC2R1cmF0aW9uX21zGAUgASgDUgpkdXJhdGlvbk1z');

@$core.Deprecated('Use updateFailedDescriptor instead')
const UpdateFailed$json = {
  '1': 'UpdateFailed',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `UpdateFailed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateFailedDescriptor = $convert.base64Decode(
    'CgxVcGRhdGVGYWlsZWQSFgoGcmVhc29uGAEgASgJUgZyZWFzb24SGAoHbWVzc2FnZRgCIAEoCV'
    'IHbWVzc2FnZQ==');
