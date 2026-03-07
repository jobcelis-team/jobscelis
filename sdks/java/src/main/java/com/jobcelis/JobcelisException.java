package com.jobcelis;

/**
 * Exception thrown when the Jobcelis API returns an error response.
 */
public class JobcelisException extends Exception {
    private final int statusCode;
    private final String detail;

    public JobcelisException(int statusCode, String detail) {
        super("Jobcelis API error " + statusCode + ": " + detail);
        this.statusCode = statusCode;
        this.detail = detail;
    }

    /** HTTP status code returned by the API. */
    public int getStatusCode() {
        return statusCode;
    }

    /** Error detail message from the API response. */
    public String getDetail() {
        return detail;
    }
}
