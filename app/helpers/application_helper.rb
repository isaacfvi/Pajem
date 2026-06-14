module ApplicationHelper
  MONTHS_PT = %w[ jan fev mar abr mai jun jul ago set out nov dez ].freeze

  def format_audit_time(time)
    "#{time.day} #{MONTHS_PT[time.month - 1]} #{time.year} às #{time.strftime('%H:%M')}"
  end
end
