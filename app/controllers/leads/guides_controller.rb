module Leads
  # The Learning Center: guides on turning an enquiry into a client.
  class GuidesController < ApplicationController
    allow_staff
    agent_tool :list_sales_guides, on: :index, title: "List the Learning Center's sales guides",
      description: "Short lessons on replying to leads, calls, questions, objections, follow-ups and closing.", next_tools: %i[show_sales_guide]
    agent_tool :show_sales_guide, on: :show, title: "Read a sales guide"

    def index
      @guides = Guide.all
      Template.seed_defaults!
      @counts = Template.group(:kind).count
    end

    def show
      @guide = Guide.find(params[:id])
    end
  end
end
