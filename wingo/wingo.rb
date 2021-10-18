require "dotenv/load"
require "mechanize"
require "mail"
require "time"
require "byebug"

@smtp_address = ENV.fetch("SMTP_ADDRESS")
@smtp_user = ENV.fetch("SMTP_USER")
@smtp_password = ENV.fetch("SMTP_PASSWORD")
@moco_mail_address = ENV.fetch("MOCO_MAIL_ADDRESS")
@wingo_user = ENV.fetch("WINGO_USER")
@wingo_password = ENV.fetch("WINGO_PASSWORD")

Mail.defaults do
  delivery_method :smtp, address: @smtp_address, port: 465, tls: true, user_name: @smtp_user, password: @smtp_password
end

def log(message)
  puts "[INFO] [#{Time.now.iso8601}] #{message}"
end

def send_mail(pdf_content, period, price)
  mail = Mail.new do
    from @smtp_user
    to @moco_mail_address
    subject "Mobilfunk Wingo: #{period}"
    body "CHF #{price}"
    add_file filename: "invoice.pdf", content: pdf_content
  end
  mail.deliver
end

m = Mechanize.new { |agent|
  agent.user_agent_alias = "Linux Firefox"
}

log("Opening mywingo.wingo.ch")

page = m.get("https://mywingo.wingo.ch")

log("Filling in form")

form = page.forms.first
form["user[id]"] = @wingo_user
form["user[password]"] = @wingo_password
landing_page = form.submit

log("Open invoices page")

invoices_page = landing_page.links.find { |link| link.text.strip == "Meine Rechnungen" }.click

first_invoice = invoices_page.css(".list-invoices").first.css("div").first

id = first_invoice.attribute("class").value.split(" ").find { |c| c.start_with?("js-invoice-") }.split("-")[-1]
period = first_invoice.css(".list-invoices__period")&.first&.text&.strip || "-"
price = first_invoice.css(".list-invoices__price")&.first&.text&.strip || "-"

log("Loading first invoice PDF")

pdf = m.get("/de/ajax_open_invoice?id=#{id}")

log("Sending email")

sent_mail = send_mail(pdf.body, period, price)

log("Message sent, id=#{sent_mail.message_id}")
