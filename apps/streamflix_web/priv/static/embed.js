/**
 * Jobcelis Embeddable Portal Widget
 * Usage:
 *   <script src="https://jobcelis.com/embed.js"></script>
 *   <div id="jobcelis-portal"></div>
 *   <script>
 *     JobcelisPortal.init({
 *       token: "emb_...",
 *       container: "#jobcelis-portal",
 *       baseUrl: "https://jobcelis.com",
 *       theme: { primaryColor: "#6366f1", logo: "https://..." },
 *       locale: "en"
 *     });
 *   </script>
 */
(function () {
  "use strict";

  var DEFAULT_BASE_URL = "https://jobcelis.com";

  var TRANSLATIONS = {
    en: {
      webhooks: "Webhooks",
      deliveries: "Deliveries",
      addWebhook: "Add Webhook",
      url: "URL",
      topics: "Topics",
      status: "Status",
      actions: "Actions",
      retry: "Retry",
      delete: "Delete",
      save: "Save",
      cancel: "Cancel",
      active: "Active",
      inactive: "Inactive",
      success: "Success",
      failed: "Failed",
      pending: "Pending",
      noWebhooks: "No webhooks configured yet.",
      noDeliveries: "No deliveries found.",
      confirmDelete: "Are you sure you want to delete this webhook?",
      retryQueued: "Retry queued",
      created: "Webhook created",
      deleted: "Webhook deleted",
      error: "An error occurred",
      loading: "Loading...",
      attempt: "Attempt",
      latency: "Latency",
      circuitOpen: "Circuit Open",
      circuitClosed: "Healthy",
    },
    es: {
      webhooks: "Webhooks",
      deliveries: "Entregas",
      addWebhook: "Agregar Webhook",
      url: "URL",
      topics: "Topics",
      status: "Estado",
      actions: "Acciones",
      retry: "Reintentar",
      delete: "Eliminar",
      save: "Guardar",
      cancel: "Cancelar",
      active: "Activo",
      inactive: "Inactivo",
      success: "Exitoso",
      failed: "Fallido",
      pending: "Pendiente",
      noWebhooks: "No hay webhooks configurados aún.",
      noDeliveries: "No se encontraron entregas.",
      confirmDelete: "¿Seguro que deseas eliminar este webhook?",
      retryQueued: "Reintento en cola",
      created: "Webhook creado",
      deleted: "Webhook eliminado",
      error: "Ocurrió un error",
      loading: "Cargando...",
      attempt: "Intento",
      latency: "Latencia",
      circuitOpen: "Circuito Abierto",
      circuitClosed: "Saludable",
    },
  };

  function JobcelisPortal() {
    this.config = null;
    this.container = null;
    this.t = TRANSLATIONS.en;
    this.currentTab = "webhooks";
    this.webhooks = [];
    this.deliveries = [];
    this.showForm = false;
  }

  JobcelisPortal.prototype.init = function (config) {
    if (!config.token) throw new Error("JobcelisPortal: token is required");
    this.config = {
      token: config.token,
      baseUrl: (config.baseUrl || DEFAULT_BASE_URL).replace(/\/$/, ""),
      theme: config.theme || {},
      locale: config.locale || "en",
      container: config.container || "#jobcelis-portal",
    };
    this.t = TRANSLATIONS[this.config.locale] || TRANSLATIONS.en;
    this.container =
      typeof this.config.container === "string"
        ? document.querySelector(this.config.container)
        : this.config.container;
    if (!this.container)
      throw new Error(
        "JobcelisPortal: container not found: " + this.config.container
      );
    this.render();
    this.loadWebhooks();
  };

  JobcelisPortal.prototype.api = function (method, path, body) {
    var self = this;
    var url = this.config.baseUrl + "/api/v1/embed" + path;
    var opts = {
      method: method,
      headers: {
        "X-Embed-Token": this.config.token,
        Accept: "application/json",
      },
    };
    if (body) {
      opts.headers["Content-Type"] = "application/json";
      opts.body = JSON.stringify(body);
    }
    return fetch(url, opts).then(function (res) {
      if (!res.ok)
        return res.json().then(function (err) {
          throw new Error(err.error || self.t.error);
        });
      return res.json();
    });
  };

  JobcelisPortal.prototype.loadWebhooks = function () {
    var self = this;
    this.api("GET", "/webhooks").then(function (res) {
      self.webhooks = res.data || [];
      self.renderContent();
    });
  };

  JobcelisPortal.prototype.loadDeliveries = function () {
    var self = this;
    this.api("GET", "/deliveries?limit=20").then(function (res) {
      self.deliveries = res.data || [];
      self.renderContent();
    });
  };

  JobcelisPortal.prototype.render = function () {
    var primary = this.config.theme.primaryColor || "#6366f1";
    var logo = this.config.theme.logo;

    this.container.innerHTML = "";
    this.container.style.fontFamily =
      '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    this.container.style.border = "1px solid #e2e8f0";
    this.container.style.borderRadius = "12px";
    this.container.style.overflow = "hidden";
    this.container.style.background = "#ffffff";

    // Header
    var header = document.createElement("div");
    header.style.cssText =
      "padding:16px 20px;background:" +
      primary +
      ";color:#fff;display:flex;align-items:center;gap:12px;";
    if (logo) {
      var img = document.createElement("img");
      img.src = logo;
      img.style.cssText = "height:28px;width:auto;";
      header.appendChild(img);
    }
    var title = document.createElement("span");
    title.textContent = "Webhook Portal";
    title.style.cssText = "font-weight:600;font-size:16px;";
    header.appendChild(title);
    this.container.appendChild(header);

    // Tabs
    var tabs = document.createElement("div");
    tabs.style.cssText =
      "display:flex;border-bottom:1px solid #e2e8f0;background:#f8fafc;";
    var self = this;
    ["webhooks", "deliveries"].forEach(function (tab) {
      var btn = document.createElement("button");
      btn.textContent = self.t[tab];
      btn.style.cssText =
        "flex:1;padding:10px;border:none;cursor:pointer;font-size:14px;background:" +
        (self.currentTab === tab ? "#fff" : "transparent") +
        ";border-bottom:" +
        (self.currentTab === tab ? "2px solid " + primary : "2px solid transparent") +
        ";color:" +
        (self.currentTab === tab ? primary : "#64748b") +
        ";font-weight:" +
        (self.currentTab === tab ? "600" : "400") +
        ";";
      btn.onclick = function () {
        self.currentTab = tab;
        self.render();
        if (tab === "webhooks") self.loadWebhooks();
        else self.loadDeliveries();
      };
      tabs.appendChild(btn);
    });
    this.container.appendChild(tabs);

    // Content area
    var content = document.createElement("div");
    content.id = "jc-portal-content";
    content.style.cssText = "padding:16px 20px;min-height:200px;";
    content.innerHTML =
      '<p style="color:#94a3b8;text-align:center;padding:40px 0;">' +
      this.t.loading +
      "</p>";
    this.container.appendChild(content);
  };

  JobcelisPortal.prototype.renderContent = function () {
    var content = document.getElementById("jc-portal-content");
    if (!content) return;
    content.innerHTML = "";

    if (this.currentTab === "webhooks") {
      this.renderWebhooks(content);
    } else {
      this.renderDeliveries(content);
    }
  };

  JobcelisPortal.prototype.renderWebhooks = function (content) {
    var self = this;
    var primary = this.config.theme.primaryColor || "#6366f1";

    // Add button
    var addBtn = document.createElement("button");
    addBtn.textContent = "+ " + this.t.addWebhook;
    addBtn.style.cssText =
      "margin-bottom:12px;padding:8px 16px;background:" +
      primary +
      ";color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:13px;";
    addBtn.onclick = function () {
      self.showForm = !self.showForm;
      self.renderContent();
    };
    content.appendChild(addBtn);

    // Form
    if (this.showForm) {
      var form = document.createElement("div");
      form.style.cssText =
        "margin-bottom:16px;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;";
      form.innerHTML =
        '<div style="margin-bottom:8px;"><label style="font-size:12px;color:#64748b;display:block;margin-bottom:4px;">' +
        this.t.url +
        '</label><input id="jc-wh-url" type="url" placeholder="https://example.com/webhook" style="width:100%;padding:8px;border:1px solid #cbd5e1;border-radius:6px;font-size:13px;box-sizing:border-box;"></div>' +
        '<div style="margin-bottom:8px;"><label style="font-size:12px;color:#64748b;display:block;margin-bottom:4px;">' +
        this.t.topics +
        ' (comma-separated)</label><input id="jc-wh-topics" placeholder="order.created, user.signup" style="width:100%;padding:8px;border:1px solid #cbd5e1;border-radius:6px;font-size:13px;box-sizing:border-box;"></div>' +
        '<div style="display:flex;gap:8px;"><button id="jc-wh-save" style="padding:8px 16px;background:' +
        primary +
        ';color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:13px;">' +
        this.t.save +
        '</button><button id="jc-wh-cancel" style="padding:8px 16px;background:#e2e8f0;color:#475569;border:none;border-radius:6px;cursor:pointer;font-size:13px;">' +
        this.t.cancel +
        "</button></div>";
      content.appendChild(form);

      document.getElementById("jc-wh-save").onclick = function () {
        var url = document.getElementById("jc-wh-url").value;
        var topics = document
          .getElementById("jc-wh-topics")
          .value.split(",")
          .map(function (t) {
            return t.trim();
          })
          .filter(Boolean);
        self
          .api("POST", "/webhooks", { url: url, topics: topics })
          .then(function () {
            self.showForm = false;
            self.loadWebhooks();
          })
          .catch(function (err) {
            alert(err.message);
          });
      };
      document.getElementById("jc-wh-cancel").onclick = function () {
        self.showForm = false;
        self.renderContent();
      };
    }

    // Table
    if (this.webhooks.length === 0) {
      content.innerHTML +=
        '<p style="color:#94a3b8;text-align:center;padding:20px;">' +
        this.t.noWebhooks +
        "</p>";
      return;
    }

    var table = document.createElement("table");
    table.style.cssText = "width:100%;border-collapse:collapse;font-size:13px;";
    table.innerHTML =
      "<thead><tr>" +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.url +
      "</th>" +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.topics +
      "</th>" +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.status +
      "</th>" +
      '<th style="text-align:right;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.actions +
      "</th>" +
      "</tr></thead>";

    var tbody = document.createElement("tbody");
    this.webhooks.forEach(function (wh) {
      var tr = document.createElement("tr");
      var circuitBadge =
        wh.circuit_state === "open"
          ? '<span style="color:#ef4444;font-size:11px;"> (' +
            self.t.circuitOpen +
            ")</span>"
          : "";
      tr.innerHTML =
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' +
        wh.url +
        "</td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;"><span style="font-size:12px;color:#64748b;">' +
        (wh.topics || []).join(", ") +
        "</span></td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;"><span style="display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;background:' +
        (wh.status === "active" ? "#dcfce7;color:#16a34a" : "#fef2f2;color:#dc2626") +
        ';">' +
        (wh.status === "active" ? self.t.active : self.t.inactive) +
        "</span>" +
        circuitBadge +
        "</td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;text-align:right;"></td>';

      var delBtn = document.createElement("button");
      delBtn.textContent = self.t.delete;
      delBtn.style.cssText =
        "padding:4px 10px;background:#fef2f2;color:#dc2626;border:none;border-radius:4px;cursor:pointer;font-size:12px;";
      delBtn.onclick = function () {
        if (confirm(self.t.confirmDelete)) {
          self
            .api("DELETE", "/webhooks/" + wh.id)
            .then(function () {
              self.loadWebhooks();
            })
            .catch(function (err) {
              alert(err.message);
            });
        }
      };
      tr.lastChild.appendChild(delBtn);
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    content.appendChild(table);
  };

  JobcelisPortal.prototype.renderDeliveries = function (content) {
    var self = this;

    if (this.deliveries.length === 0) {
      content.innerHTML =
        '<p style="color:#94a3b8;text-align:center;padding:20px;">' +
        this.t.noDeliveries +
        "</p>";
      return;
    }

    var table = document.createElement("table");
    table.style.cssText = "width:100%;border-collapse:collapse;font-size:13px;";
    table.innerHTML =
      "<thead><tr>" +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.status +
      "</th>" +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">HTTP</th>' +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.attempt +
      "</th>" +
      '<th style="text-align:left;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.latency +
      "</th>" +
      '<th style="text-align:right;padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-weight:500;">' +
      this.t.actions +
      "</th>" +
      "</tr></thead>";

    var tbody = document.createElement("tbody");
    this.deliveries.forEach(function (d) {
      var tr = document.createElement("tr");
      var statusColor =
        d.status === "success"
          ? "#16a34a"
          : d.status === "failed"
            ? "#dc2626"
            : "#f59e0b";
      var statusBg =
        d.status === "success"
          ? "#dcfce7"
          : d.status === "failed"
            ? "#fef2f2"
            : "#fefce8";
      tr.innerHTML =
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;"><span style="display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;background:' +
        statusBg +
        ";color:" +
        statusColor +
        ';">' +
        d.status +
        "</span></td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;">' +
        (d.response_status || "-") +
        "</td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;">' +
        d.attempt_number +
        "</td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;">' +
        (d.response_latency_ms ? d.response_latency_ms + "ms" : "-") +
        "</td>" +
        '<td style="padding:8px;border-bottom:1px solid #f1f5f9;text-align:right;"></td>';

      if (d.status === "failed") {
        var retryBtn = document.createElement("button");
        retryBtn.textContent = self.t.retry;
        retryBtn.style.cssText =
          "padding:4px 10px;background:#eff6ff;color:#2563eb;border:none;border-radius:4px;cursor:pointer;font-size:12px;";
        retryBtn.onclick = function () {
          self
            .api("POST", "/deliveries/" + d.id + "/retry")
            .then(function () {
              self.loadDeliveries();
            })
            .catch(function (err) {
              alert(err.message);
            });
        };
        tr.lastChild.appendChild(retryBtn);
      }
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    content.appendChild(table);
  };

  // Export
  window.JobcelisPortal = new JobcelisPortal();
})();
