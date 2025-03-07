require "./action"

class CB::ClusterCreate < CB::APIAction
  bool_setter ha
  name_setter? name
  ident_setter plan
  property platform : String?
  i32_setter postgres_version
  ident_setter region
  i32_setter storage
  eid_setter team, "team id"
  eid_setter network, "network id"
  eid_setter replica, "replica id"
  eid_setter fork, "fork id"
  property at : Time?

  def pre_validate
    if (id = fork || replica)
      source = client.get_cluster id

      @name ||= "#{fork ? "Fork" : "Replica"} of #{source.name}"
      @platform ||= source.provider_id
      @region ||= source.region_id
      @storage ||= source.storage
      @plan ||= source.plan_id
      @network ||= source.network_id
    else
      @storage ||= 100
      @name ||= "Cluster #{Time.utc.to_s("%F %H_%M_%S")}"
    end
  end

  def run
    validate

    params = {
      "is_ha":               @ha,
      "name":                @name,
      "plan_id":             @plan,
      "provider_id":         @platform,
      "postgres_version_id": @postgres_version,
      "region_id":           @region,
      "storage":             @storage,
      "team_id":             @team,
      "network_id":          @network,
    }

    cluster = if fork
                @client.fork_cluster self
              elsif replica
                @client.replicate_cluster self
              else
                @client.create_cluster params
              end

    @output << "Created cluster #{cluster.id.colorize.t_id} \"#{cluster.name.colorize.t_name}\"\n"
  end

  def validate
    pre_validate
    check_required_args do |missing|
      missing << "ha" if ha.nil?
      missing << "name" unless name
      missing << "plan" unless plan
      missing << "platform" unless platform
      missing << "region" unless region
      missing << "storage" unless storage
      missing << "team" unless team || fork || replica
    end
  end

  def at=(str : String)
    @at = Time.parse_rfc3339(str).to_utc
  rescue Time::Format::Error
    raise_arg_error "at (not RFC3339)", str
  end

  def platform=(str : String)
    str = str.downcase
    str = "azure" if str == "azr"
    raise_arg_error "platform", str unless str == "azure" || str == "gcp" || str == "aws"
    @platform = str
  end
end
