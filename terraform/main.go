// Jobcelis Terraform Provider
//
// This provider allows managing Jobcelis resources (webhooks, pipelines, event schemas)
// as infrastructure-as-code using Terraform.
//
// Usage in Terraform:
//
//	terraform {
//	  required_providers {
//	    jobcelis = {
//	      source = "jobcelis/jobcelis"
//	    }
//	  }
//	}
//
//	provider "jobcelis" {
//	  api_key = var.jobcelis_api_key
//	  # base_url = "https://jobcelis.com"  # optional
//	}
package main

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/v2/plugin"
)

func main() {
	plugin.Serve(&plugin.ServeOpts{
		ProviderFunc: Provider,
	})
}

// Provider returns the Jobcelis Terraform provider.
func Provider() *schema.Provider {
	return &schema.Provider{
		Schema: map[string]*schema.Schema{
			"api_key": {
				Type:        schema.TypeString,
				Required:    true,
				Sensitive:   true,
				DefaultFunc: schema.EnvDefaultFunc("JOBCELIS_API_KEY", nil),
				Description: "API key for authenticating with the Jobcelis platform.",
			},
			"base_url": {
				Type:        schema.TypeString,
				Optional:    true,
				Default:     "https://jobcelis.com",
				DefaultFunc: schema.EnvDefaultFunc("JOBCELIS_URL", "https://jobcelis.com"),
				Description: "Base URL of the Jobcelis API.",
			},
		},
		ResourcesMap: map[string]*schema.Resource{
			"jobcelis_webhook":  resourceWebhook(),
			"jobcelis_pipeline": resourcePipeline(),
		},
		DataSourcesMap: map[string]*schema.Resource{
			"jobcelis_webhook":  dataSourceWebhook(),
			"jobcelis_pipeline": dataSourcePipeline(),
		},
		ConfigureContextFunc: providerConfigure,
	}
}

func providerConfigure(_ context.Context, d *schema.ResourceData) (interface{}, diag.Diagnostics) {
	apiKey := d.Get("api_key").(string)
	baseURL := d.Get("base_url").(string)

	if apiKey == "" {
		return nil, diag.Errorf("api_key is required")
	}

	return &ProviderConfig{
		APIKey:  apiKey,
		BaseURL: baseURL,
	}, nil
}

// ProviderConfig holds the provider configuration.
type ProviderConfig struct {
	APIKey  string
	BaseURL string
}

// placeholder — full CRUD in resource files
func resourceWebhook() *schema.Resource {
	return &schema.Resource{
		Description:   "Manages a Jobcelis webhook endpoint.",
		CreateContext: resourceWebhookCreate,
		ReadContext:   resourceWebhookRead,
		UpdateContext: resourceWebhookUpdate,
		DeleteContext: resourceWebhookDelete,
		Schema: map[string]*schema.Schema{
			"url": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "The destination URL for webhook deliveries.",
			},
			"secret": {
				Type:        schema.TypeString,
				Optional:    true,
				Sensitive:   true,
				Description: "Secret used for HMAC-SHA256 signature verification.",
			},
			"topics": {
				Type:        schema.TypeList,
				Optional:    true,
				Description: "List of event topic patterns to subscribe to (supports wildcards).",
				Elem:        &schema.Schema{Type: schema.TypeString},
			},
			"status": {
				Type:        schema.TypeString,
				Computed:    true,
				Description: "Current status of the webhook (active/inactive).",
			},
		},
	}
}

func resourcePipeline() *schema.Resource {
	return &schema.Resource{
		Description:   "Manages a Jobcelis event pipeline.",
		CreateContext: resourcePipelineCreate,
		ReadContext:   resourcePipelineRead,
		UpdateContext: resourcePipelineUpdate,
		DeleteContext: resourcePipelineDelete,
		Schema: map[string]*schema.Schema{
			"name": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "Name of the pipeline.",
			},
			"description": {
				Type:        schema.TypeString,
				Optional:    true,
				Description: "Description of what this pipeline does.",
			},
			"webhook_id": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "ID of the target webhook for delivery.",
			},
			"topics": {
				Type:        schema.TypeList,
				Optional:    true,
				Description: "Event topic patterns that trigger this pipeline.",
				Elem:        &schema.Schema{Type: schema.TypeString},
			},
			"steps": {
				Type:        schema.TypeString,
				Optional:    true,
				Description: "JSON-encoded array of pipeline steps.",
			},
			"status": {
				Type:        schema.TypeString,
				Computed:    true,
				Description: "Current status (active/inactive).",
			},
		},
	}
}

func dataSourceWebhook() *schema.Resource {
	return &schema.Resource{
		Description: "Retrieves information about an existing Jobcelis webhook.",
		ReadContext: dataSourceWebhookRead,
		Schema: map[string]*schema.Schema{
			"webhook_id": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "The ID of the webhook to look up.",
			},
			"url": {Type: schema.TypeString, Computed: true},
			"status": {Type: schema.TypeString, Computed: true},
			"topics": {Type: schema.TypeList, Computed: true, Elem: &schema.Schema{Type: schema.TypeString}},
		},
	}
}

func dataSourcePipeline() *schema.Resource {
	return &schema.Resource{
		Description: "Retrieves information about an existing Jobcelis pipeline.",
		ReadContext: dataSourcePipelineRead,
		Schema: map[string]*schema.Schema{
			"pipeline_id": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "The ID of the pipeline to look up.",
			},
			"name": {Type: schema.TypeString, Computed: true},
			"status": {Type: schema.TypeString, Computed: true},
			"webhook_id": {Type: schema.TypeString, Computed: true},
		},
	}
}

// Stub CRUD functions — these would make HTTP calls to the Jobcelis API
// using the ProviderConfig. Full implementation when provider is published.

func resourceWebhookCreate(_ context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	_ = m.(*ProviderConfig)
	d.SetId(fmt.Sprintf("webhook-%s", d.Get("url").(string)))
	return nil
}

func resourceWebhookRead(_ context.Context, _ *schema.ResourceData, _ interface{}) diag.Diagnostics {
	return nil
}

func resourceWebhookUpdate(_ context.Context, _ *schema.ResourceData, _ interface{}) diag.Diagnostics {
	return nil
}

func resourceWebhookDelete(_ context.Context, d *schema.ResourceData, _ interface{}) diag.Diagnostics {
	d.SetId("")
	return nil
}

func resourcePipelineCreate(_ context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	_ = m.(*ProviderConfig)
	d.SetId(fmt.Sprintf("pipeline-%s", d.Get("name").(string)))
	return nil
}

func resourcePipelineRead(_ context.Context, _ *schema.ResourceData, _ interface{}) diag.Diagnostics {
	return nil
}

func resourcePipelineUpdate(_ context.Context, _ *schema.ResourceData, _ interface{}) diag.Diagnostics {
	return nil
}

func resourcePipelineDelete(_ context.Context, d *schema.ResourceData, _ interface{}) diag.Diagnostics {
	d.SetId("")
	return nil
}

func dataSourceWebhookRead(_ context.Context, _ *schema.ResourceData, _ interface{}) diag.Diagnostics {
	return nil
}

func dataSourcePipelineRead(_ context.Context, _ *schema.ResourceData, _ interface{}) diag.Diagnostics {
	return nil
}
