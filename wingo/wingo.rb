require "dotenv/load"
require "mechanize"
require "time"
require "date"
require "byebug"
require "base64"
require "faraday"
require "faraday/net_http"
Faraday.default_adapter = :net_http

@wingo_user = ENV.fetch("WINGO_USER")
@wingo_password = ENV.fetch("WINGO_PASSWORD")
@moco_api_key = ENV.fetch("MOCO_API_KEY")

def log(message)
  puts "[INFO] [#{Time.now.iso8601}] #{message}"
end

m = Mechanize.new { |agent|
  agent.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36"
}

log("Opening mywingo.wingo.ch")

page = m.get("https://mywingo.wingo.ch/eCare/de/users/sign_in")

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

log("Posting receipt...")

prev = Date.today.prev_month
last_month_end_of_month = Date.civil(prev.year, prev.month, -1)

payload = {
  date: last_month_end_of_month.to_s,
  title: "Mobilfunk Wingo: #{period} TEST",
  items: [
    {
      vat_code_id: 325,
      gross_total: Float(price),
    },
  ],
  attachment: {
    filename: "wingo_invoice.pdf",
    base64: Base64.encode64(pdf.body),
  },
}

response = Faraday.post("https://intern.mocoapp.com/api/v1/receipts", payload.to_json, {
  "Content-Type" => "application/json",
  "Authorization" => "Token token=#{@moco_api_key}",
})
log("Request sent, status: #{response.status}")
