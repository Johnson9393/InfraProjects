#locals we use to combine/transform the input values into reusuable internal values
locals {
  name_prefix = "${var.env}-${var.project}"
}