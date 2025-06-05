import { log as shared_log } from "../../../../../lib/log.ts";

let log_level = 2;
const log_level_string = Deno.env.get("LOG_LEVEL");
if (log_level_string === undefined) {
    console.error("!ALERT!: service: supabase - LOG_LEVEL is not set; defaulting to 2 (error)");
} else {
    const log_level_number = Number.parseInt(log_level_string);
    if (isNaN(log_level_number)) {
        console.error("!ALERT!: service: supabase - LOG_LEVEL is not a number; defaulting to 2 (error)");
    }
    log_level = log_level_number;
}

/**
 * Logs a message with a specified log level.
 * Acts as a wrapper for the shared logger, with the
 * log level and service name populated by default.
 * 
 * @param level - The log level of the message to be logged.
 * Levels correspond directly to the log levels defined
 * in the shared logger.
 * @param message - The log message to be recorded.
 */
export function log(
    level: number,
    message: string
): void {
    shared_log(level, log_level, "supabase", message);
}