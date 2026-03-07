package com.jobcelis

/**
 * Exception thrown when the Jobcelis API returns an error response.
 *
 * @property statusCode HTTP status code returned by the API.
 * @property detail Error detail message from the API response.
 */
class JobcelisException(
    val statusCode: Int,
    val detail: String
) : Exception("Jobcelis API error $statusCode: $detail")
