defmodule StreamflixWebWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>

          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("cerrar")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label class="block text-slate-700 dark:text-slate-300 text-sm font-medium mb-1">
        <span :if={@label}>{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[
            @class ||
              "w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label class="block text-slate-700 dark:text-slate-300 text-sm font-medium mb-1">
        <span :if={@label}>{@label}</span> <textarea
          id={@id}
          name={@name}
          class={[
            @class ||
              "w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "password"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label :if={@label} class="block text-slate-700 dark:text-slate-300 text-sm font-medium mb-1">
        <span>{@label}</span>
      </label>
      <div class="relative" id={"#{@id}-pw-wrap"} phx-hook="PasswordToggle">
        <input
          type="password"
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value("password", @value)}
          class={[
            @class ||
              "w-full pl-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
            "!pr-12",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        />
        <button
          type="button"
          data-pw-toggle-btn
          tabindex="-1"
          class="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-md text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300 focus:outline-none transition-colors"
        >
          <svg
            data-pw-icon-show
            class="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
            />
          </svg>
          <svg
            data-pw-icon-hide
            class="w-5 h-5 hidden"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
            />
          </svg>
        </button>
      </div>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label class="block text-slate-700 dark:text-slate-300 text-sm font-medium mb-1">
        <span :if={@label}>{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class ||
              "w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-red-600 dark:text-red-400">
      <.icon name="hero-exclamation-circle" class="size-5" /> {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">{render_slot(@inner_block)}</h1>

        <p :if={@subtitle != []} class="text-sm text-base-content/70">{render_slot(@subtitle)}</p>
      </div>

      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>

          <th :if={@action != []}><span class="sr-only">{gettext("Acciones")}</span></th>
        </tr>
      </thead>

      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>

          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>

          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a tooltip that appears on hover.

  ## Attributes

    * `text` — tooltip text (required)
    * `position` — `"top"` (default) or `"bottom"`

  ## Examples

      <.tooltip text="This is helpful info">
        <.icon name="hero-question-mark-circle" class="w-4 h-4 text-slate-400" />
      </.tooltip>

      <.tooltip text="Below the element" position="bottom">
        <span>Hover me</span>
      </.tooltip>
  """
  attr :text, :string, required: true
  attr :position, :string, default: "top", values: ~w(top bottom)
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <span class="group/tip relative inline-flex items-center cursor-help">
      {render_slot(@inner_block)}
      <span class={[
        "pointer-events-none invisible opacity-0 group-hover/tip:visible group-hover/tip:opacity-100",
        "absolute left-1/2 -translate-x-1/2 px-3 py-2 text-xs leading-relaxed text-white",
        "bg-slate-800 dark:bg-slate-700 rounded-lg whitespace-normal max-w-xs w-max text-center",
        "shadow-lg z-[100] transition-opacity duration-150",
        @position == "top" && "bottom-full mb-2",
        @position == "bottom" && "top-full mt-2"
      ]}>
        {@text}
        <span class={[
          "absolute left-1/2 -translate-x-1/2 border-4 border-transparent",
          @position == "top" && "top-full border-t-slate-800 dark:border-t-slate-700",
          @position == "bottom" && "bottom-full border-b-slate-800 dark:border-b-slate-700"
        ]}>
        </span>
      </span>
    </span>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders a custom confirmation modal triggered by phx-click.

  Replaces browser `data-confirm` with a styled modal.

  ## Examples

      <.confirm_modal
        id="delete-schema-confirm"
        title={gettext("Confirmar eliminación")}
        message={gettext("¿Eliminar este schema?")}
        confirm_text={gettext("Eliminar")}
        confirm_event="delete_schema"
        confirm_value={%{id: schema.id}}
        variant="danger"
      />
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :message, :string, required: true
  attr :confirm_text, :string, default: nil
  attr :cancel_text, :string, default: nil
  attr :confirm_event, :string, required: true
  attr :confirm_value, :map, default: %{}
  attr :variant, :string, default: "danger", values: ~w(danger warning)

  def confirm_modal(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.title || gettext("Confirmar acción"))
      |> assign(:confirm_text, assigns.confirm_text || gettext("Confirmar"))
      |> assign(:cancel_text, assigns.cancel_text || gettext("Cancelar"))

    ~H"""
    <div
      id={@id}
      class="hidden fixed inset-0 z-[60] flex items-center justify-center p-4"
      phx-mounted={JS.add_class("hidden", to: "##{@id}")}
    >
      <div
        class="absolute inset-0 bg-black/50 backdrop-blur-sm"
        phx-click={hide_confirm(@id)}
        aria-hidden="true"
      >
      </div>
      <div
        class="relative z-10 bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-sm mx-auto p-6 border border-slate-200/50 dark:border-slate-700"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-desc"}
      >
        <div class="flex items-start gap-4">
          <div class={[
            "flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center",
            @variant == "danger" && "bg-red-100 dark:bg-red-900/30",
            @variant == "warning" && "bg-amber-100 dark:bg-amber-900/30"
          ]}>
            <.icon
              name="hero-exclamation-triangle"
              class={[
                "w-5 h-5",
                @variant == "danger" && "text-red-600 dark:text-red-400",
                @variant == "warning" && "text-amber-600 dark:text-amber-400"
              ]}
            />
          </div>
          <div class="flex-1 min-w-0">
            <h3
              id={"#{@id}-title"}
              class="text-base font-semibold text-slate-900 dark:text-slate-100"
            >
              {@title}
            </h3>
            <p id={"#{@id}-desc"} class="mt-1 text-sm text-slate-500 dark:text-slate-400">
              {@message}
            </p>
          </div>
        </div>
        <div class="mt-5 flex justify-end gap-3">
          <button
            type="button"
            phx-click={hide_confirm(@id)}
            class="px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-600 transition"
          >
            {@cancel_text}
          </button>
          <button
            type="button"
            phx-click={JS.push(@confirm_event, value: @confirm_value) |> hide_confirm(@id)}
            class={[
              "px-4 py-2 text-sm font-medium text-white rounded-lg transition",
              @variant == "danger" && "bg-red-600 hover:bg-red-700",
              @variant == "warning" && "bg-amber-600 hover:bg-amber-700"
            ]}
          >
            {@confirm_text}
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Shows a confirmation modal by ID. Used with `phx-click` on trigger buttons.
  """
  def show_confirm(js \\ %JS{}, id) do
    js
    |> JS.remove_class("hidden", to: "##{id}")
    |> JS.transition({"ease-out duration-200", "opacity-0", "opacity-100"}, to: "##{id}")
  end

  defp hide_confirm(js \\ %JS{}, id) do
    js
    |> JS.transition({"ease-in duration-150", "opacity-100", "opacity-0"}, to: "##{id}")
    |> JS.add_class("hidden", to: "##{id}")
  end

  @doc """
  Renders a skeleton loading placeholder.

  ## Examples

      <.skeleton type="card" />
      <.skeleton type="table" rows={5} />
      <.skeleton type="text" lines={3} />
  """
  attr :type, :string, default: "card", values: ~w(card table text stat)
  attr :rows, :integer, default: 3
  attr :lines, :integer, default: 3

  def skeleton(assigns) do
    ~H"""
    <%= case @type do %>
      <% "card" -> %>
        <div class="animate-pulse rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-6">
          <div class="h-4 bg-slate-200 dark:bg-slate-700 rounded w-1/3 mb-4"></div>
          <div class="space-y-3">
            <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-full"></div>
            <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-5/6"></div>
            <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-4/6"></div>
          </div>
        </div>
      <% "table" -> %>
        <div class="animate-pulse">
          <div class="h-10 bg-slate-100 dark:bg-slate-700/50 rounded-t-lg mb-1"></div>
          <%= for _i <- 1..@rows do %>
            <div class="flex gap-4 py-3 px-4 border-b border-slate-100 dark:border-slate-700">
              <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-1/4"></div>
              <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-1/3"></div>
              <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-1/6"></div>
              <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-1/5"></div>
            </div>
          <% end %>
        </div>
      <% "text" -> %>
        <div class="animate-pulse space-y-2">
          <%= for _i <- 1..@lines do %>
            <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-full"></div>
          <% end %>
        </div>
      <% "stat" -> %>
        <div class="animate-pulse flex items-center gap-4 p-4 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800">
          <div class="w-12 h-12 bg-slate-200 dark:bg-slate-700 rounded-full"></div>
          <div class="flex-1">
            <div class="h-3 bg-slate-200 dark:bg-slate-700 rounded w-1/2 mb-2"></div>
            <div class="h-5 bg-slate-200 dark:bg-slate-700 rounded w-1/3"></div>
          </div>
        </div>
    <% end %>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(StreamflixWebWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(StreamflixWebWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
