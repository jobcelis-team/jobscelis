defmodule StreamflixCore.Schemas.InputLimitsTest do
  use ExUnit.Case, async: true

  alias StreamflixCore.Schemas.{Job, Pipeline, Project, Webhook}

  @project_id Ecto.UUID.generate()

  defp webhook_changeset(topics) do
    Webhook.changeset(%Webhook{}, %{
      project_id: @project_id,
      url: "https://93.184.216.34/hook",
      topics: topics
    })
  end

  describe "webhook topics" do
    test "accepts plain topic patterns" do
      cs = webhook_changeset(["order.created", "user.*", "payment.#", "a:b-c_d"])
      refute cs.errors[:topics]
    end

    test "rejects markup" do
      cs = webhook_changeset(["<img src=x onerror=alert(1)>"])
      assert cs.errors[:topics]
    end

    test "rejects topics longer than 100 characters" do
      assert webhook_changeset([String.duplicate("a", 101)]).errors[:topics]
      refute webhook_changeset([String.duplicate("a", 100)]).errors[:topics]
    end

    test "rejects more than 50 topics" do
      topics = for i <- 1..51, do: "t#{i}"
      assert webhook_changeset(topics).errors[:topics]
    end
  end

  describe "name and description lengths" do
    test "project name is limited to 100 characters" do
      cs = Project.changeset(%Project{}, %{name: String.duplicate("p", 101)})
      assert cs.errors[:name]
    end

    test "job name is limited to 100 characters" do
      cs = Job.changeset(%Job{}, %{name: String.duplicate("j", 101)})
      assert cs.errors[:name]
    end

    test "pipeline name and description are limited" do
      cs =
        Pipeline.changeset(%Pipeline{}, %{
          name: String.duplicate("n", 101),
          description: String.duplicate("d", 501)
        })

      assert cs.errors[:name]
      assert cs.errors[:description]
    end
  end
end
