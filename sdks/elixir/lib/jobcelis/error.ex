defmodule Jobcelis.Error do
  @moduledoc """
  Error returned when the Jobcelis API returns a non-success status code.
  """

  defexception [:status, :detail]

  @type t :: %__MODULE__{
          status: integer(),
          detail: any()
        }

  @impl true
  def message(%__MODULE__{status: status, detail: detail}) do
    "HTTP #{status}: #{inspect(detail)}"
  end
end
