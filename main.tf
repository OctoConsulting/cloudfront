resource "aws_s3_bucket" "www_site" {
  bucket = "www.${var.site_name}"
  logging {
    target_bucket = "www.${var.site_name}"
  }
  website {
    index_document = "index.html"
  }
}


//Two ways of handling this 
//1 Don’t manage the certificate with terraform. Create it manually and drop the ARN of the certificate wherever you need to use it.
//2 Manage the certificate with terraform, but create it manually and then use terraform import to import the resource AFTER its been approved and created.
resource "aws_acm_certificate" "cert" {
  domain = "www.example.com" //change this to the domain for project
}


//create cloudfront 
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "cloudfront origin access identity"
}
resource "aws_cloudfront_distribution" "website_cdn" {
  enabled      = true
  price_class  = "PriceClass_200"
  http_version = "http1.1"
  aliases = ["www.${var.site_name}"]
  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.www_site.id}"
    domain_name = "www.${var.site_name}.s3.us-east-2.amazonaws.com"
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.www_site.id}"
    min_ttl          = "0"
    default_ttl      = "300"                                              //3600
    max_ttl          = "1200"                                             //86400
    // This redirects any HTTP request to HTTPS. Security first!
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn      = "${aws_acm_certificate.cert.arn}"
    ssl_support_method       = "sni-only"
  }
}

//bucket policy 
data "template_file" "bucket_policy" {
    template = "${file("bucket_policy.json")}"
    vars {
        origin_access_identity_arn = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
        bucket = "${aws_s3_bucket.www_site.arn}"
    }
}
resource "aws_s3_bucket" "www_site" {
  bucket = "www.${var.site_name}"
  policy = "${data.template_file.bucket_policy.rendered}"
}

//Create DNS Resource 
resource "aws_route53_record" "www_site" {
  zone_id = "${data.aws_route53_zone.site.zone_id}"
  name = "www.${var.site_name}"
  type = "A"
  alias {
    name = "${aws_cloudfront_distribution.website_cdn.domain_name}"
    zone_id  = "${aws_cloudfront_distribution.website_cdn.hosted_zone_id}"
    evaluate_target_health = false
  }
}
