/**
 * MCP Secrets Sync Worker
 *
 * Stores and retrieves MCP server secrets from Cloudflare KV.
 * Requires AUTH_TOKEN secret for authentication.
 */

interface Env {
  SECRETS_KV: KVNamespace;
  AUTH_TOKEN: string;
  ENVIRONMENT: string;
}

const SECRETS_KEY = 'mcp-secrets-v1';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Verify auth token
    const authHeader = request.headers.get('Authorization');
    const token = authHeader?.replace('Bearer ', '');

    if (!token || token !== env.AUTH_TOKEN) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Routes
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'healthy', environment: env.ENVIRONMENT }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (url.pathname === '/secrets' && request.method === 'GET') {
      // Pull secrets
      const secrets = await env.SECRETS_KV.get(SECRETS_KEY);

      if (!secrets) {
        return new Response(JSON.stringify({ error: 'No secrets found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response(secrets, {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (url.pathname === '/secrets' && request.method === 'POST') {
      // Push secrets
      try {
        const body = await request.json() as Record<string, string>;

        // Validate it's a flat object of strings
        for (const [key, value] of Object.entries(body)) {
          if (typeof key !== 'string' || typeof value !== 'string') {
            return new Response(JSON.stringify({ error: 'Secrets must be string key-value pairs' }), {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }
        }

        await env.SECRETS_KV.put(SECRETS_KEY, JSON.stringify(body));

        return new Response(JSON.stringify({
          success: true,
          message: `Stored ${Object.keys(body).length} secrets`,
          keys: Object.keys(body)
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } catch (e) {
        return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    if (url.pathname === '/secrets/keys' && request.method === 'GET') {
      // List secret keys (without values)
      const secrets = await env.SECRETS_KV.get(SECRETS_KEY);

      if (!secrets) {
        return new Response(JSON.stringify({ keys: [] }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const parsed = JSON.parse(secrets);
      return new Response(JSON.stringify({ keys: Object.keys(parsed) }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({
      error: 'Not found',
      endpoints: {
        'GET /health': 'Health check',
        'GET /secrets': 'Pull all secrets',
        'POST /secrets': 'Push secrets (JSON body)',
        'GET /secrets/keys': 'List secret keys'
      }
    }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  },
};
