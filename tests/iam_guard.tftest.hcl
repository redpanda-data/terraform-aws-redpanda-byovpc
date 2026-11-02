# Renders the module's IAM without AWS credentials so tests/iam_guard.py can check the agent's
# effective permissions. Run with `terraform test -json -verbose | python3 tests/iam_guard.py`.
#
# The AWS provider is mocked, so nothing calls AWS. A plan can't be used: Terraform defers every data
# source that references a resource with pending changes, so the agent's policy documents would stay
# unknown. Under apply the mock fills aws_iam_policy_document's json with a placeholder, but the state
# keeps each document's evaluated statement blocks, and iam_guard.py evaluates those.
#
# Every IAM role, policy and instance profile is overridden below with the name AWS would generate
# from its name_prefix. iam_guard.py matches these against the policies' resource patterns, so a
# made-up ARN could hide a self-inclusive wildcard. A resource without an override gets the
# NOT-OVERRIDDEN ARN from the mock below, and iam_guard.py fails naming it.

mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::000000000000:role/NOT-OVERRIDDEN"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::000000000000:policy/NOT-OVERRIDDEN"
    }
  }

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::000000000000:instance-profile/NOT-OVERRIDDEN"
    }
  }

  # Policy arguments are validated as JSON even under the mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Security group rules validate CIDRs taken from these.
  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      cidr_block = "10.0.0.0/24"
    }
  }
}

variables {
  region         = "us-east-2"
  aws_account_id = "123456789012"
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

override_data {
  target = data.aws_availability_zones.available_additional_zones
  values = {
    zone_ids = ["use2-az1", "use2-az2", "use2-az3"]
    names    = ["us-east-2a", "us-east-2b", "us-east-2c"]
  }
}


# The agent's policy documents get distinct placeholder JSON so iam_guard.py can tell which document
# each attached policy came from. A new document attached to the agent needs an entry here.

override_data {
  target = data.aws_iam_policy_document.redpanda_agent1
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"redpanda_agent1\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.redpanda_agent2
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"redpanda_agent2\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.agent_permissions_boundary_scoped_iam
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"agent_permissions_boundary_scoped_iam\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.redpanda_agent4
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"redpanda_agent4\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.redpanda_agent5
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"redpanda_agent5\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.redpanda_agent_private_link
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"redpanda_agent_private_link\",\"Statement\":[]}"
  }
}

# IAM roles

override_resource {
  target = aws_iam_role.redpanda_agent
  values = {
    name = "redpanda-agent-20261102000000000000000001"
    arn  = "arn:aws:iam::123456789012:role/redpanda-agent-20261102000000000000000001"
  }
}

override_resource {
  target = aws_iam_role.redpanda_node_group
  values = {
    name = "redpanda-rp-20261102000000000000000002"
    arn  = "arn:aws:iam::123456789012:role/redpanda-rp-20261102000000000000000002"
  }
}

override_resource {
  target = aws_iam_role.redpanda_utility_node_group
  values = {
    name = "redpanda-util-20261102000000000000000003"
    arn  = "arn:aws:iam::123456789012:role/redpanda-util-20261102000000000000000003"
  }
}

override_resource {
  target = aws_iam_role.connectors_node_group
  values = {
    name = "redpanda-connect-20261102000000000000000004"
    arn  = "arn:aws:iam::123456789012:role/redpanda-connect-20261102000000000000000004"
  }
}

override_resource {
  target = aws_iam_role.k8s_cluster
  values = {
    name = "redpanda-cluster-20261102000000000000000005"
    arn  = "arn:aws:iam::123456789012:role/redpanda-cluster-20261102000000000000000005"
  }
}

override_resource {
  target = aws_iam_role.redpanda_connect_node_group
  values = {
    name = "redpanda-rpcn-20261102000000000000000006"
    arn  = "arn:aws:iam::123456789012:role/redpanda-rpcn-20261102000000000000000006"
  }
}

override_resource {
  target = aws_iam_role.rpsql_node_group
  values = {
    name = "redpanda-rpsql-20261102000000000000000007"
    arn  = "arn:aws:iam::123456789012:role/redpanda-rpsql-20261102000000000000000007"
  }
}

# Instance profiles

override_resource {
  target = aws_iam_instance_profile.redpanda_agent
  values = {
    arn = "arn:aws:iam::123456789012:instance-profile/redpanda-agent-20261102000000000000000011"
  }
}

override_resource {
  target = aws_iam_instance_profile.redpanda_node_group
  values = {
    arn = "arn:aws:iam::123456789012:instance-profile/redpanda-rp-20261102000000000000000012"
  }
}

override_resource {
  target = aws_iam_instance_profile.utility
  values = {
    arn = "arn:aws:iam::123456789012:instance-profile/redpanda-util-20261102000000000000000013"
  }
}

override_resource {
  target = aws_iam_instance_profile.connectors_node_group
  values = {
    arn = "arn:aws:iam::123456789012:instance-profile/redpanda-connect-20261102000000000000000014"
  }
}

override_resource {
  target = aws_iam_instance_profile.redpanda_connect_node_group
  values = {
    arn = "arn:aws:iam::123456789012:instance-profile/redpanda-rpcn-20261102000000000000000015"
  }
}

override_resource {
  target = aws_iam_instance_profile.rpsql_node_group
  values = {
    arn = "arn:aws:iam::123456789012:instance-profile/redpanda-rpsql-20261102000000000000000016"
  }
}

# Managed policies

override_resource {
  target = aws_iam_policy.redpanda_agent["1"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-1-20261102000000000000000021"
  }
}

override_resource {
  target = aws_iam_policy.redpanda_agent["2"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-2-20261102000000000000000022"
  }
}

override_resource {
  target = aws_iam_policy.redpanda_agent["3"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-3-20261102000000000000000023"
  }
}

override_resource {
  target = aws_iam_policy.redpanda_agent["4"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-4-20261102000000000000000024"
  }
}

override_resource {
  target = aws_iam_policy.redpanda_agent["5"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-5-20261102000000000000000025"
  }
}

override_resource {
  target = aws_iam_policy.redpanda_agent_private_link
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-pl-20261102000000000000000026"
  }
}

override_resource {
  target = aws_iam_policy.agent_permission_boundary
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-agent-boundary-20261102000000000000000027"
  }
}

override_resource {
  target = aws_iam_policy.aws_ebs_csi_driver_policy
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-aws_ebs_csi_driver-20261102000000000000000031"
  }
}

override_resource {
  target = aws_iam_policy.cert_manager
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-cert_manager_policy-20261102000000000000000032"
  }
}

override_resource {
  target = aws_iam_policy.external_dns_policy
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-external_dns_policy-20261102000000000000000033"
  }
}

override_resource {
  target = aws_iam_policy.load_balancer_controller_policy["1"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-load_balancer_controller_1-20261102000000000000000034"
  }
}

override_resource {
  target = aws_iam_policy.load_balancer_controller_policy["2"]
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-load_balancer_controller_2-20261102000000000000000035"
  }
}

override_resource {
  target = aws_iam_policy.cluster_autoscaler_policy
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-rp-autoscaler-20261102000000000000000036"
  }
}

override_resource {
  target = aws_iam_policy.glue_iceberg
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-glue-iceberg-20261102000000000000000037"
  }
}

override_resource {
  target = aws_iam_policy.glue_iceberg_read_only
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-glue-iceberg-ro-20261102000000000000000038"
  }
}

override_resource {
  target = aws_iam_policy.byovpc_rpk_user_1
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-rpk-user-1_20261102000000000000000039"
  }
}

override_resource {
  target = aws_iam_policy.byovpc_rpk_user_2
  values = {
    arn = "arn:aws:iam::123456789012:policy/redpanda-rpk-user-2_20261102000000000000000040"
  }
}

run "defaults" {
  command = apply
}

run "all_features" {
  command = apply

  variables {
    enable_private_link         = true
    enable_redpanda_connect     = true
    enable_redpanda_sql         = true
    enable_glue_iceberg_catalog = true
    create_rpk_user             = true
  }
}
