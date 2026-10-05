# Reorder file sections so doc-signal files come first, drop imports and
# brace-only lines, and collapse long runs of removed lines; the byte cap
# then cuts the least useful code.
function prio(p) {
  if (p ~ /\.(json|ya?ml|properties|sql|toml|ini|conf)$/ || p ~ /(^|\/)(conf|config|migrations?|locale\/languages\/en-us)/) return 0
  if (p ~ /\.(md|mdx|rst)$/) return 0
  if (p ~ /\.(tsx?|jsx?)$/) return 1
  return 2
}
function flush_run() {
  if (run > 8) { sec[n] = sec[n] r1 r2 r3 sprintf("-[... %d more removed lines]\n", run - 3) }
  else sec[n] = sec[n] rbuf
  run = 0; rbuf = ""; r1 = r2 = r3 = ""
}
/^=== / { if (n) flush_run(); n++; pr[n] = prio($2); sec[n] = $0 "\n"; next }
n == 0 { next }
# Imports and brace-only lines carry no doc signal.
/^[+ -][[:space:]]*(import |from [A-Za-z0-9_.]+ import |package [a-z]|using [A-Z]|#include )/ { next }
/^[+ -][[:space:]]*[{}()\[\];,]*[[:space:]]*$/ { next }
/^-/ { run++; rbuf = rbuf $0 "\n"; if (run == 1) r1 = $0 "\n"; else if (run == 2) r2 = $0 "\n"; else if (run == 3) r3 = $0 "\n"; next }
{ flush_run(); sec[n] = sec[n] $0 "\n" }
END { if (n) flush_run(); for (p = 0; p <= 2; p++) for (i = 1; i <= n; i++) if (pr[i] == p) printf "%s", sec[i] }
