defmodule Mix.Tasks.NervesHubCa.Init do
  alias NervesHubCA.CertificateTemplate

  @path Path.join(File.cwd!(), "etc/ssl")

  @switches [
    path: :string,
    host: :string
  ]

  def run(args) do
    {opts, _args} = OptionParser.parse!(args, strict: @switches)

    path = opts[:path] || Application.get_env(:nerves_hub_ca, :working_dir) || @path
    host = opts[:host] || "nerves-hub.org"
    File.mkdir_p(path)

    # Generate Self-Signed Root
    {root_ca, root_ca_key} = gen_root_ca_cert("NervesHub Root CA")

    write_certs(root_ca, root_ca_key, "root-ca", path)

    # Generate Device certs
    {device_root_ca, device_root_ca_key} =
      gen_int_ca_cert(root_ca, root_ca_key, "NervesHub Device Root CA", 0)

    write_certs(device_root_ca, device_root_ca_key, "device-root-ca", path)

    # Generate User certs
    {user_root_ca, user_root_ca_key} =
      gen_int_ca_cert(root_ca, root_ca_key, "NervesHub User Root CA", 0)

    write_certs(user_root_ca, user_root_ca_key, "user-root-ca", path)

    # Generate Server certs
    {server_root_ca, server_root_ca_key} =
      gen_int_ca_cert(root_ca, root_ca_key, "NervesHub Server Root CA", 0)

    {ca_server, ca_server_key} =
      gen_server_cert(server_root_ca, server_root_ca_key, "NervesHub CA Server", [
        "ca.#{host}"
      ])

    {api_server, api_server_key} =
      gen_server_cert(server_root_ca, server_root_ca_key, "NervesHub API Server", [
        "api.#{host}"
      ])

    {device_server, device_server_key} =
      gen_server_cert(server_root_ca, server_root_ca_key, "NervesHub Device Server", [
        "device.#{host}"
      ])

    write_certs(server_root_ca, server_root_ca_key, "server-root-ca", path)
    write_certs(ca_server, ca_server_key, "ca.#{host}", path)
    write_certs(api_server, api_server_key, "api.#{host}", path)
    write_certs(device_server, device_server_key, "device.#{host}", path)

    ca_bundle_path = Path.join(path, "ca.pem")

    ca_bundle =
      X509.Certificate.to_pem(root_ca) <>
        X509.Certificate.to_pem(user_root_ca) <>
        X509.Certificate.to_pem(server_root_ca) <> X509.Certificate.to_pem(device_root_ca)

    File.write(ca_bundle_path, ca_bundle)
  end

  defp gen_server_cert(issuer, issuer_key, common_name, subject_alt_names) do
    opts = [
      hash: CertificateTemplate.hash(),
      validity: NervesHubCA.CertificateTemplate.years(5),
      extensions: [
        subject_alt_name: X509.Certificate.Extension.subject_alt_name(subject_alt_names)
      ]
    ]

    X509.Certificate.Template.new(:server, opts)
    |> gen_cert(issuer, issuer_key, common_name)
  end

  defp gen_int_ca_cert(issuer, issuer_key, common_name, path_length) do
    opts = [
      serial: {:random, CertificateTemplate.serial_number_bytes()},
      validity: NervesHubCA.CertificateTemplate.years(10),
      hash: CertificateTemplate.hash(),
      extensions: [
        basic_constraints: X509.Certificate.Extension.basic_constraints(true, path_length),
        ext_key_usage: false
      ]
    ]

    X509.Certificate.Template.new(:ca, opts)
    |> gen_cert(issuer, issuer_key, common_name)
  end

  defp gen_root_ca_cert(common_name) do
    opts = [
      serial: {:random, CertificateTemplate.serial_number_bytes()},
      validity: NervesHubCA.CertificateTemplate.years(30),
      hash: CertificateTemplate.hash(),
      extensions: [
        key_usage: X509.Certificate.Extension.key_usage([:keyCertSign, :cRLSign]),
        basic_constraints: X509.Certificate.Extension.basic_constraints(true),
        subject_key_identifier: true,
        authority_key_identifier: false
      ]
    ]

    template = X509.Certificate.Template.new(:root_ca, opts)
    ca_key = X509.PrivateKey.new_ec(CertificateTemplate.ec_named_curve())
    subject_rdn = Path.join(CertificateTemplate.subject_rdn(), "CN=" <> common_name)
    ca = X509.Certificate.self_signed(ca_key, subject_rdn, template: template)
    {ca, ca_key}
  end

  defp gen_cert(template, issuer, issuer_key, common_name) do
    private_key = X509.PrivateKey.new_ec(CertificateTemplate.ec_named_curve())
    public_key = X509.PublicKey.derive(private_key)
    subject_rdn = Path.join(CertificateTemplate.subject_rdn(), "CN=" <> common_name)
    ca = X509.Certificate.new(public_key, subject_rdn, issuer, issuer_key, template: template)
    {ca, private_key}
  end

  defp write_certs(cert, private_key, name, path) do
    cert = X509.Certificate.to_pem(cert)
    private_key = X509.PrivateKey.to_pem(private_key)

    cert_path = Path.join(path, "#{name}.pem")
    File.write!(cert_path, cert)

    private_key_path = Path.join(path, "#{name}-key.pem")
    File.write!(private_key_path, private_key)
  end
end
