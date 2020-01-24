local ngx_now = ngx.now

local zipkin_span = require "kong.plugins.zipkin.span"
local zipkin_span_context = require "kong.plugins.zipkin.span_context"

local math_random = math.random

local tracer_methods = {}
local tracer_mt = {
  __index = tracer_methods,
}

local function new(sample_ratio)
  return setmetatable({
    sample_ratio = sample_ratio,
  }, tracer_mt)
end

function tracer_methods:start_span(name, options)
  local context, child_of, tags, start_timestamp
  if options ~= nil then
    child_of = options.child_of
    if child_of ~= nil then
      if type(child_of.context) == "function" then -- get the context instead of the span, if given a span
        child_of = child_of:context()
      end
    end
    tags = options.tags
    if tags ~= nil then
      assert(type(tags) == "table", "tags should be a table")
    end
    start_timestamp = options.start_timestamp
    -- Allow zipkin_span.new to validate
  end
  if start_timestamp == nil then
    start_timestamp = ngx_now()
  end
  if child_of then
    context = child_of:child()
  else
    local should_sample = math_random() < self.sample_ratio
    context = zipkin_span_context.new(nil, nil, nil, should_sample)
  end
  local span = zipkin_span.new(context, name, start_timestamp)
  if tags then
    for k, v in pairs(tags) do
      span:set_tag(k, v)
    end
  end
  return span
end

return {
  new = new,
}
