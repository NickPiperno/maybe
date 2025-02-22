class ScenariosController < ApplicationController
  layout :with_sidebar

  def index
    @scenarios = Current.family.scenarios.order(created_at: :desc)
  end

  def show
    @scenario = Current.family.scenarios.find(params[:id])
  end

  def simulate
    @scenario = Scenario.new
  end

  def create
    @scenario = Current.family.scenarios.build(scenario_params)
    
    if @scenario.save
      redirect_to scenarios_path, notice: 'Scenario was successfully created.'
    else
      render :simulate, status: :unprocessable_entity
    end
  end

  private

  def scenario_params
    params.require(:scenario).permit(
      :name,
      :description,
      :income_adjustment,
      :expense_adjustment,
      :savings_rate,
      :timeline_months
    )
  end
end 