<?php

declare(strict_types=1);

namespace Jobcelis;

/**
 * Exception thrown when the Jobcelis API returns an error.
 */
class JobcelisException extends \Exception
{
    public readonly int $statusCode;
    public readonly mixed $detail;

    public function __construct(int $statusCode, mixed $detail)
    {
        $this->statusCode = $statusCode;
        $this->detail = $detail;

        $message = is_string($detail)
            ? "HTTP {$statusCode}: {$detail}"
            : "HTTP {$statusCode}: " . json_encode($detail);

        parent::__construct($message, $statusCode);
    }
}
