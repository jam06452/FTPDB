defmodule Ftpdb.Slack do
  def suggest(category, display_name, message, title) do

    config = Application.get_env(:ftpdb, :slack)
    my_id = config[:id]
    token = config[:token]

    url = "https://slack.com/api/chat.postMessage"

    body = %{
      channel: my_id,
      text: "New #{category} from #{display_name}",
      blocks: [
        %{
          type: "header",
          text: %{type: "plain_text", text: "📬 New #{String.capitalize(category)} Received"}
        },
        %{
          type: "section",
          text: %{
            type: "mrkdwn",
            text: "*User:* `#{display_name}`\n*Title:* `#{title}`\n*Category:* `#{category}`\n*Message:* \n>#{message}"
          }
        },
        %{
          type: "context",
          elements: [
            %{type: "mrkdwn", text: "Submitted via Webapp Suggestions Form"}
          ]
        }
      ]
    }

    Req.post(url,
      auth: {:bearer, token},
      json: body
    )
    |> case do
      {:ok, %{status: 200, body: %{"ok" => true}}} -> :ok
      {:ok, %{body: %{"error" => error}}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end
end
