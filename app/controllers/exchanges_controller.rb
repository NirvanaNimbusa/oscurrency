class ExchangesController < ApplicationController
  skip_before_filter :require_activation
  before_filter :login_or_oauth_required
  before_filter :find_worker

  def index
    @exchanges = @worker.received_exchanges # created_at DESC
    respond_to do |format|
      format.xml { render :xml => @exchanges }
      format.json { render :json => @exchanges.to_json( :include => :req ) }
    end
  end

  def show
    @exchange = Exchange.find(params[:id])
    respond_to do |format|
      format.xml { render :xml => @exchange.to_xml( :include => :req ) }
      format.json { render :json => @exchange.to_json( :include => :req ) }
    end
  end

  def new
    @exchange = Exchange.new

    if params[:offer]
      @offer = Offer.find(params[:offer])
      if @offer.person != Person.find(params[:person_id])
        flash[:error] = "Specified offer does not match person"
      end
    else
      @req = Req.new
      @req.name = 'Enter description of service here'
    end

    @groups = current_person.groups
  end

  # this method expects that the form is either referencing an existing offer or accepting a name field for a new req to be created 
  #
  def create
    @exchange = Exchange.new(params[:exchange]) # amount and group_id are the only accessible fields
    @exchange.worker = @worker
    unless (current_person.accountant? or current_person.admin?) and @exchange.customer
      @exchange.customer = current_person
    end

    if params[:offer]
      @offer = Offer.find(params[:offer][:id])
      @exchange.amount = @offer.price
      @exchange.metadata = @offer
    else
      @req = Req.new(params[:req])

      @req.name = 'Gift transfer' if @req.name.blank? # XML creation might not set this
      @req.estimated_hours = @exchange.amount
      @req.due_date = Time.now
      @req.person = current_person
      @req.active = false
      @req.save!

      @exchange.metadata = @req
    end


    respond_to do |format|
      if @exchange.save
        flash[:notice] = "Credit transfer succeeded."
        format.html { redirect_to person_path(@worker) and return }
        format.xml { render :xml => @exchange, :status => :created, :location => [@worker, @exchange] }
        format.json { render :json => @exchange, :status => :created, :location => [@worker, @exchange] }
      else
        flash[:error] = "Error with credit transfer."
        @groups = Person.find(params[:person_id]).groups
        format.html { render :action => "new" }
        format.xml { render :xml => @exchange.errors, :status => :unprocessable_entity }
        format.json { render :json => @exchange.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @exchange = Exchange.find(params[:id])

    @exchange.destroy
    flash[:success] = "Payment suspended."

    respond_to do |format|
      format.html { redirect_to person_url(current_person) }
    end
  end

private
  def find_worker
    @worker_id = params[:person_id]
    redirect_to home_url and return unless @worker_id
    @worker = Person.find(@worker_id)
  end
end
