export function finding(id, subject, message) {
  return { id, subject, message: String(message) };
}

export function compareFindings(left, right) {
  return left.id.localeCompare(right.id, 'en')
    || left.subject.localeCompare(right.subject, 'en')
    || left.message.localeCompare(right.message, 'en');
}
