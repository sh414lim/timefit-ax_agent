/// Candidate-only rejection codes for an unapproved chat wire shape.
///
/// These values are intentionally not exported from a production barrel and
/// must not be treated as the approved backend contract.
enum CandidateContractFailureCode {
  contractInvalid('candidate_contract_invalid'),
  unsupportedSchemaVersion('candidate_unsupported_schema_version'),
  invalidUuid('candidate_invalid_uuid'),
  invalidUtcTimestamp('candidate_invalid_utc_timestamp'),
  unsafeInteger('candidate_unsafe_integer'),
  inputBudgetExceeded('candidate_input_budget_exceeded'),
  unknownEnum('candidate_unknown_enum'),
  conversationMismatch('candidate_conversation_mismatch'),
  nonContiguousSequence('candidate_non_contiguous_sequence'),
  cursorPolicyViolation('candidate_cursor_policy_violation'),
  unapprovedAttachmentSchema('candidate_unapproved_attachment_schema');

  const CandidateContractFailureCode(this.stableCode);

  final String stableCode;
}

final class CandidateContractFailure {
  const CandidateContractFailure(this.code);

  final CandidateContractFailureCode code;

  @override
  String toString() => 'CandidateContractFailure(${code.stableCode})';
}

sealed class CandidateDecodeResult<T> {
  const CandidateDecodeResult();
}

final class CandidateDecoded<T> extends CandidateDecodeResult<T> {
  const CandidateDecoded(this.value);

  final T value;
}

final class CandidateRejected<T> extends CandidateDecodeResult<T> {
  const CandidateRejected(this.failure);

  final CandidateContractFailure failure;
}
