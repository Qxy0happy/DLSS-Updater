// This is a generated file - do not edit.
//
// Generated from dlss/v1/update.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class UpdateOutcome extends $pb.ProtobufEnum {
  static const UpdateOutcome UPDATE_OUTCOME_UNSPECIFIED =
      UpdateOutcome._(0, _omitEnumNames ? '' : 'UPDATE_OUTCOME_UNSPECIFIED');
  static const UpdateOutcome UPDATE_OUTCOME_UPDATED =
      UpdateOutcome._(1, _omitEnumNames ? '' : 'UPDATE_OUTCOME_UPDATED');
  static const UpdateOutcome UPDATE_OUTCOME_SKIPPED =
      UpdateOutcome._(2, _omitEnumNames ? '' : 'UPDATE_OUTCOME_SKIPPED');
  static const UpdateOutcome UPDATE_OUTCOME_FAILED =
      UpdateOutcome._(3, _omitEnumNames ? '' : 'UPDATE_OUTCOME_FAILED');

  static const $core.List<UpdateOutcome> values = <UpdateOutcome>[
    UPDATE_OUTCOME_UNSPECIFIED,
    UPDATE_OUTCOME_UPDATED,
    UPDATE_OUTCOME_SKIPPED,
    UPDATE_OUTCOME_FAILED,
  ];

  static final $core.List<UpdateOutcome?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static UpdateOutcome? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UpdateOutcome._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
