require "./action"

class CB::ClusterInfo < CB::APIAction
  cluster_identifier_setter cluster_id

  def validate
    check_required_args do |missing|
      missing << "cluster" if @cluster_id.empty?
    end
  end

  def run
    validate

    c = client.get_cluster(cluster_id[:cluster])
    cluster_status = client.get_cluster_status cluster_id: c.id

    print_team_slash_cluster c

    details = {
      "state"              => cluster_status.state,
      "host"               => c.host,
      "created"            => c.created_at.to_rfc3339,
      "plan"               => "#{c.plan_id} (#{format(c.memory)}GiB ram, #{format(c.cpu)}vCPU)",
      "version"            => c.major_version,
      "storage"            => "#{c.storage}GiB",
      "ha"                 => (c.is_ha ? "on" : "off"),
      "platform"           => c.provider_id,
      "region"             => c.region_id,
      "maintenance window" => MaintenanceWindow.new(c.maintenance_window_start).explain,
    }

    if source = c.source_cluster_id
      details["source cluster"] = source
    end

    details["network"] = c.network_id if c.network_id

    pad = (details.keys.map(&.size).max || 8) + 2
    details.each do |k, v|
      output << k.rjust(pad).colorize.bold << ": "
      output << v << "\n"
    end

    firewall_rules = client.get_firewall_rules c.network_id
    output << "firewall".rjust(pad).colorize.bold << ": "
    if firewall_rules.empty?
      output << "no rules\n"
    else
      output << "allowed cidrs".colorize.underline << "\n"
    end
    firewall_rules.each { |fr| output << " "*(pad + 4) << fr.rule << "\n" }
  end
end
