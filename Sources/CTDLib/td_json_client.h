#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Creates a new TDLib client and returns its ID.
int td_create_client_id(void);

// Sends a request to TDLib. The request is a JSON-encoded object.
void td_send(int client_id, const char *request);

// Receives an incoming update or a response to a request from TDLib.
// Blocks for up to `timeout` seconds. Returns NULL if nothing received.
const char *td_receive(double timeout);

// Synchronously executes a TDLib request. Only a few requests can be executed synchronously.
const char *td_execute(const char *request);

typedef void (*td_log_message_callback_ptr)(int verbosity_level, const char *message);
void td_set_log_message_callback(int max_verbosity_level, td_log_message_callback_ptr callback);

#ifdef __cplusplus
}
#endif
