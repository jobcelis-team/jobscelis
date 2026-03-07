namespace Jobcelis;

/// <summary>
/// Exception thrown when the Jobcelis API returns an error.
/// </summary>
public class JobcelisException : Exception
{
    /// <summary>HTTP status code.</summary>
    public int StatusCode { get; }

    /// <summary>Error detail from the API response.</summary>
    public object? Detail { get; }

    public JobcelisException(int statusCode, object? detail)
        : base($"HTTP {statusCode}: {detail}")
    {
        StatusCode = statusCode;
        Detail = detail;
    }
}
