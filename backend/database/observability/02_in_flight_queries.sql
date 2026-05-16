-- Currently-running queries, ordered by how long they've been active.
-- This is the "what is taking so long *right now*" view. Anything sitting
-- at the top with a multi-minute runtime + state = 'active' is a live
-- candidate for a hung upsert or stuck dbt model.
--
-- Filters out:
--   - the session running this query (pid <> pg_backend_pid())
--   - idle connections with no work in progress (state = 'idle')
--   - autovacuum workers (often long-running and expected)
--
-- Notes:
--   wait_event_type / wait_event       - if non-null, the backend is blocked
--                                        (Lock, IO, IPC...). 'Lock' means
--                                        another session is holding what
--                                        this one wants -- see blocked_by.
--   blocked_by                         - array of pids holding locks this
--                                        query is waiting on. Empty array
--                                        = not blocked.
--   query                              - truncated to 500 chars for
--                                        readability. Remove substr() to
--                                        see the full statement.

SELECT
    pid,
    usename                                       AS user,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    pg_blocking_pids(pid)                         AS blocked_by,
    now() - xact_start                            AS xact_age,
    now() - query_start                           AS query_age,
    substr(query, 1, 500)                         AS query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND state <> 'idle'
  AND backend_type = 'client backend'
ORDER BY query_start ASC NULLS LAST;
