/**
 * Removes every trailing `char` from `value`.
 *
 * A loop instead of a regex such as /=+$/: on input made of many repeated
 * characters not followed by the end, that regex backtracks quadratically.
 */
export function trimTrailing(value: string, char: string): string {
  let end = value.length;
  while (end > 0 && value[end - 1] === char) end--;
  return value.slice(0, end);
}
