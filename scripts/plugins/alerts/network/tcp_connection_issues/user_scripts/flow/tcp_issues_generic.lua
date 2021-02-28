--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require ("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

-- NOTE: this module is always enabled
local script = {
   packet_interface_only = true,
  
   -- Script category
   category = user_scripts.script_categories.network,

   nedge_exclude = true,
   l4_proto = "tcp",
   three_way_handshake_ok = true,

   -- This script is only for alerts generation
   is_alert = true,

   default_value = {
      severity = alert_severities.warning,
   },

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.tcp_issues_generic",
      i18n_description = "flow_callbacks_config.tcp_issues_generic_description",
   }
}

local min_issues_count = 10 -- At least 10 packets
local normal_issues_ratio = 10	-- 1/10
local severe_issues_ratio = 3	-- 1/3

-- #################################################################

local function check_tcp_issues(now, conf)
   local is_client = false -- Does the client have TCP issues?
   local is_server = false -- Does the server have TCP issues?
   local is_severe = false -- Whether the exceeded one is the severe threshold

   -- Client -> Server
   local cli_issues = flow.getClientTCPIssues()

   if(cli_issues > min_issues_count) then
      local cli2srv_pkts = flow.getPacketsSent()

      if((cli_issues * severe_issues_ratio) > cli2srv_pkts) then
	 is_client = true
	 is_severe = true
      elseif((cli_issues * normal_issues_ratio) > cli2srv_pkts) then
	 is_client = true
      end
   end

   -- Server -> Client
   local srv_issues = flow.getServerTCPIssues()
   if(srv_issues > min_issues_count) then
      local srv2cli_pkts = flow.getPacketsRcvd()

      if((srv_issues * severe_issues_ratio) > srv2cli_pkts) then
	 is_server = true
	 is_severe = true
      elseif((srv_issues * normal_issues_ratio) > srv2cli_pkts) then
	 is_server = true
      end
   end

   -- Now it's time to generate the alert, it either the client or the server has issues

   if is_client or is_server then
      if is_severe then
         local alert = alert_consts.alert_types.alert_connection_issues.new(
            flow.getTCPStats(),
            flow.getPacketsSent(),
            flow.getPacketsRcvd(),
            true, -- Severe issues
            is_client,
            is_server
         )

         alert:set_severity(conf.severity)

         alert:trigger_status(20, 20, 20)

      else
         local alert = alert_consts.alert_types.alert_connection_issues.new(
            flow.getTCPStats(),
            flow.getPacketsSent(),
            flow.getPacketsRcvd(),
            false, -- Issues are NOT severe
            is_client,
            is_server
         )

         alert:set_severity(alert_severities.info)

         alert:trigger_status(10, 10, 10)
      end
   end
end

-- #################################################################

script.hooks.flowEnd = check_tcp_issues
script.hooks.periodicUpdate = check_tcp_issues

-- #################################################################

return script
