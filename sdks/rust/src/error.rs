use thiserror::Error;

/// Error returned by Jobcelis API operations.
#[derive(Error, Debug)]
pub enum JobcelisError {
    /// HTTP error from the API.
    #[error("HTTP {status}: {detail}")]
    Api {
        status: u16,
        detail: serde_json::Value,
    },

    /// Network or request error.
    #[error("Request error: {0}")]
    Request(#[from] reqwest::Error),

    /// JSON serialization/deserialization error.
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}
