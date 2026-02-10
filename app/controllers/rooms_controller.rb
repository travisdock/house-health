class RoomsController < ApplicationController
  before_action :set_room, only: %i[edit update destroy]

  def index
    @rooms = Room.includes(tasks: :completions).all
  end

  def new
    @room = Room.new
  end

  def create
    @room = Room.new(room_params)
    if @room.save
      respond_to do |format|
        format.html { redirect_back fallback_location: rooms_path }
        format.json { render json: @room.as_json(only: %i[id name x y width height]), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @room.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      redirect_to rooms_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room.destroy
    redirect_to rooms_path
  end

  def position
    @room = Room.find(params[:id])
    @room.assign_attributes(position_params)
    if @room.valid?
      @room.update_columns(position_params.to_h)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def room_params
    params.expect(room: [ :name, :x, :y, :width, :height ])
  end

  def position_params
    params.expect(room: [ :x, :y, :width, :height ])
  end
end
