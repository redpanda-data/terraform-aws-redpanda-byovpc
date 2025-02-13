// -----------------------------
// Redpanda Agent security group
// -----------------------------
resource "aws_security_group" "redpanda_agent" {
  name_prefix = "${var.common_prefix}-agent-"
  description = "Redpanda agent VM"
  vpc_id      = data.aws_vpc.redpanda.id
  ingress     = []
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

// -----------------------------
// Connectors security group
// -----------------------------
resource "aws_security_group" "connectors" {
  name_prefix = "${var.common_prefix}-connect-"
  description = "Redpanda connectors nodes"
  vpc_id      = data.aws_vpc.redpanda.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "connectors" {
  security_group_id = aws_security_group.connectors.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  description       = "Allow all egress traffic"
  cidr_blocks       = ["0.0.0.0/0"]
}

// -----------------------------
// Utility security group
// -----------------------------
resource "aws_security_group" "utility" {
  name_prefix = "${var.common_prefix}-util-"
  description = "Redpanda utility nodes"
  vpc_id      = data.aws_vpc.redpanda.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "utility" {
  security_group_id = aws_security_group.utility.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  description       = "Allow all egress traffic"
  cidr_blocks       = ["0.0.0.0/0"]
}

// ----------------------------------
// Redpanda Node Group security group
// ----------------------------------
resource "aws_security_group" "redpanda_node_group" {
  name_prefix = "${var.common_prefix}-rp-"
  description = "Redpanda cluster nodes"
  vpc_id      = data.aws_vpc.redpanda.id
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  rp_node_group_cidr_blocks = [
    // RFC 6598 reserved prefix for shared address space
    // https://datatracker.ietf.org/doc/html/rfc6598
    "100.64.0.0/10",

    // RFC 1918 reserved IP address space for private internets
    // https://datatracker.ietf.org/doc/html/rfc1918
    "172.16.0.0/12",
    "192.168.0.0/16",
    "10.0.0.0/8",
  ]
}

resource "aws_security_group_rule" "redpanda_node_group" {
  security_group_id = aws_security_group.redpanda_node_group.id
  protocol          = "tcp"
  from_port         = 30092
  to_port           = 30094
  type              = "ingress"
  description       = "Allow access to Kafka API in the ports advertised by Redpanda brokers"
  cidr_blocks       = local.rp_node_group_cidr_blocks
}

// -----------------------------
// Cluster security group
// -----------------------------
resource "aws_security_group" "cluster" {
  name_prefix = "${var.common_prefix}-cluster-"
  description = "EKS cluster security group"
  vpc_id      = data.aws_vpc.redpanda.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster_node_groups_to_cluster_api" {
  description              = "Node groups to cluster API"
  security_group_id        = aws_security_group.cluster.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  source_security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "cluster_agent_to_cluster_api" {
  description       = "Redpanda Agent to K8s Cluster"
  security_group_id = aws_security_group.cluster.id
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  type              = "ingress"
  # cidr blocks must include the IP address of the Redpanda Agent VM
  cidr_blocks = data.aws_subnet.private[*].cidr_block
}

resource "aws_security_group_rule" "cluster_api_to_node_group" {
  description              = "Cluster API to node groups"
  security_group_id        = aws_security_group.cluster.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  type                     = "egress"
  source_security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "cluster_egress_nodes_kubelet" {
  description              = "Cluster API to node kubelets"
  security_group_id        = aws_security_group.cluster.id
  protocol                 = "tcp"
  from_port                = 10250
  to_port                  = 10250
  type                     = "egress"
  source_security_group_id = aws_security_group.node.id
}

// -----------------------------
// Node security group
// -----------------------------
resource "aws_security_group" "node" {
  name_prefix = "${var.common_prefix}-node-"
  description = "EKS node shared security group"
  vpc_id      = data.aws_vpc.redpanda.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "node_groups_to_cluster_api" {
  description              = "Node groups to cluster API"
  security_group_id        = aws_security_group.node.id
  protocol                 = "tcp"
  from_port                = "443"
  to_port                  = "443"
  type                     = "egress"
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_api_to_node_groups" {
  description              = "Cluster API to node groups"
  security_group_id        = aws_security_group.node.id
  protocol                 = "tcp"
  from_port                = "443"
  to_port                  = "443"
  type                     = "ingress"
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_api_to_node_kubelets" {
  description              = "Cluster API to node kubelets"
  security_group_id        = aws_security_group.node.id
  protocol                 = "tcp"
  from_port                = "10250"
  to_port                  = "10250"
  type                     = "ingress"
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "node_to_node_coredns" {
  description       = "Node to node CoreDNS"
  security_group_id = aws_security_group.node.id
  protocol          = "tcp"
  from_port         = "53"
  to_port           = "53"
  type              = "ingress"
  self              = true
}

resource "aws_security_group_rule" "node_to_node_coredns_egress" {
  description       = "Node to node CoreDNS"
  security_group_id = aws_security_group.node.id
  protocol          = "tcp"
  from_port         = "53"
  to_port           = "53"
  type              = "egress"
  self              = true
}

resource "aws_security_group_rule" "node_to_node_coredns_udp" {
  description       = "Node to node CoreDNS"
  security_group_id = aws_security_group.node.id
  protocol          = "udp"
  from_port         = "53"
  to_port           = "53"
  type              = "ingress"
  self              = true
}

resource "aws_security_group_rule" "node_to_node_coredns_udp_egress" {
  description       = "Node to node CoreDNS"
  security_group_id = aws_security_group.node.id
  protocol          = "udp"
  from_port         = "53"
  to_port           = "53"
  type              = "egress"
  self              = true
}

resource "aws_security_group_rule" "egress_all_https_to_internet" {
  description       = "Egress all HTTPS to internet"
  security_group_id = aws_security_group.node.id
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_ntp_tcp_to_internet" {
  description       = "Egress NTP/TCP to internet"
  security_group_id = aws_security_group.node.id
  protocol          = "tcp"
  from_port         = "123"
  to_port           = "123"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_ntp_udp_to_internet" {
  description       = "Egress NTP/UDP to internet"
  security_group_id = aws_security_group.node.id
  protocol          = "udp"
  from_port         = "123"
  to_port           = "123"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
