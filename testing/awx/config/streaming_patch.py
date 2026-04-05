"""Monkey-patch ansible_runner.streaming.Processor.run to handle empty EOF lines.

When receptor closes the work unit socket, AWX reads b'' (EOF) which json.loads
cannot parse, causing jobs to be marked as 'error' even though they succeeded.
This patch treats empty lines as a clean EOF instead of a JSON parse error.
"""
import ansible_runner.streaming

_original_run = ansible_runner.streaming.Processor.run


def _patched_run(self):
    import json
    import os

    job_events_path = os.path.join(self.artifact_dir, 'job_events')
    if not os.path.exists(job_events_path):
        os.makedirs(job_events_path, 0o700, exist_ok=True)

    while True:
        try:
            line = self._input.readline()
            if not line or line.strip() == b'' or line.strip() == '':
                break  # Clean EOF
            data = json.loads(line)
        except (json.decoder.JSONDecodeError, IOError):
            # Skip non-JSON lines instead of treating them as fatal errors
            continue

        if 'status' in data:
            self.status_callback(data)
        elif 'zipfile' in data:
            self.artifacts_callback(data)
        elif 'eof' in data:
            break
        elif data.get('event') == 'keepalive':
            continue
        else:
            self.event_callback(data)

    if self.finished_callback is not None:
        self.finished_callback(self)

    return self.status, self.rc


ansible_runner.streaming.Processor.run = _patched_run
