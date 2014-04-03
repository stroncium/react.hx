package rx.core;

enum CompositeLifecycle {
  Mounting;
  Unmounting;
  ReceivingProps;
  ReceivingState;
}

class CompositeComponent<T> extends rx.core.Component {

  private var compositeLifecycleState: CompositeLifecycle;

  private var state: T;
  private var pendingState: T;
  private var pendingForceUpdate: Bool;
  private var defaultProps: rx.core.Descriptor.Props;
  private var pendingContext: rx.core.Context;
  private var renderedComponent: rx.core.Component;

  public function new() {
    super(new rx.core.Descriptor(null, null));

    state = null;
    pendingState = null;
    pendingForceUpdate = false;
    context = null;
    compositeLifecycleState = null;

  }
  public override function isMounted():Bool {
    return super.isMounted();
  }

  public function getInitialState():T {
    return null;
  }

  public function getDefaultProps():rx.core.Descriptor.Props {
    return null;
  }

  public function componentWillMount():Void {}
  public function componentDidMount():Void {}

  public function componentWillUpdate(props, state, context):Void {}
  public function componentDidUpdate(props, state, context):Void {}

  public function componentWillReceiveProps(props, context):Void {}

  public function shouldComponentUpdate(props, state, context): Bool {
    return true;
  }

  public function render():rx.core.Component { return null; }

  private function renderValidatedComponent():rx.core.Component {

    var renderedComponent = null;
    var previousContext = Context.current;
    // Context.current = 
    rx.core.Owner.current = this;
    try {
      renderedComponent = this.render();
    } catch(e:js.Error) {
      trace(e.stack);
    }
    // Context.current = prev;
    rx.core.Owner.current = null;

    return renderedComponent;
  }

  public override function mountComponent(rootId: String, transaction: rx.browser.ReconcileTransaction, mountDepth:Int):String {

    super.mountComponent(rootId, transaction, mountDepth);
    compositeLifecycleState = CompositeLifecycle.Mounting;

    // context = processContext(context);
    defaultProps = getDefaultProps();
    // props = processProps(props);

    state = getInitialState();
    pendingState = null;
    pendingForceUpdate = false;

    componentWillMount();
    if (pendingState != null) {
      state = pendingState;
      pendingState = null;
    }

    renderedComponent = renderValidatedComponent();

    compositeLifecycleState = null;

    var markup = renderedComponent.mountComponent(rootId, transaction, mountDepth + 1);
    transaction.getMountReady().enqueue(this, componentDidMount);
    return markup;
  }

  public function setState(state: T) {
    pendingState = state;
    digest();
  }

  public function digest(?callback: Dynamic) {
    pendingForceUpdate = true;
    rx.core.Updates.enqueueUpdate(this, callback);
  }

  public override function receiveComponent(nextComponent:rx.core.Component, transaction:rx.browser.ReconcileTransaction) {
    if (nextComponent.props == this.props && nextComponent.owner != null) {
      // Since props and context are immutable after the component is
      // mounted, we can do a cheap identity compare here to determine
      // if this is a superfluous reconcile.
      return;
    }
    
    super.receiveComponent(
      nextComponent,
      transaction
    );
  }

  public override function updateComponent(
    transaction:rx.browser.ReconcileTransaction, 
    prevProps:rx.core.Descriptor.Props, 
    prevOwner: rx.core.Owner, 
    ?prevState: Dynamic, 
    ?prevContext: Dynamic) {

    super.updateComponent(transaction, prevProps, prevOwner);

    var prevComponent = renderedComponent;
    var nextComponent = renderValidatedComponent();

    if (rx.core.Component.shouldUpdate(prevComponent, nextComponent)) {
      prevComponent.receiveComponent(nextComponent, transaction);
    } else {
      
      var thisId = rootNodeId;
      var prevComponentId = prevComponent.rootNodeId;
      prevComponent.unmountComponent();
      var nextMarkup = renderedComponent.mountComponent(thisId, transaction, mountDepth + 1);

      rx.browser.ui.dom.IdOperations.dangerouslyReplaceNodeWithMarkupById(prevComponentId, nextMarkup);
    }

  }

  public function _performComponentUpdate(
    nextProps: rx.core.Descriptor.Props,
    nextOwner: rx.core.Owner,
    nextState: T,
    nextContext: rx.core.Context,
    transaction: rx.browser.ReconcileTransaction) {

    this.componentWillUpdate(nextProps, nextState, nextContext);

    var prevProps = this.props;
    var prevState = this.state;
    var prevContext = this.context;

    this.props = nextProps;
    this.owner = nextOwner;
    this.state = nextState;
    this.context = nextContext;

    this.updateComponent(transaction, prevProps, owner);

    transaction.getMountReady().enqueue(this, componentDidUpdate, [prevProps, prevState, prevContext]);

  }

  public function processProps(pendingProps: rx.core.Descriptor.Props):rx.core.Descriptor.Props {
    return pendingProps;
  }

  public function processContext(pendingContext: rx.core.Context):rx.core.Context {
    return pendingContext;
  }

  public override function _performUpdateIfNecessary(transaction: rx.browser.ReconcileTransaction) {
    if (this.pendingProps == null &&
        this.pendingState == null &&
        this.pendingContext == null &&
        !this.pendingForceUpdate) {
      return;
    }

    var nextFullContext = this.pendingContext;
    if (nextFullContext == null) nextFullContext = this.context;
    var nextContext = this.processContext(nextFullContext);
    this.pendingContext = null;

    var nextProps = this.props;
    if (this.pendingProps != null) {
      nextProps = this.processProps(this.pendingProps);
      this.pendingProps = null;

      this.compositeLifecycleState = CompositeLifecycle.ReceivingProps;
      this.componentWillReceiveProps(nextProps, nextContext);
    }
    

    compositeLifecycleState = CompositeLifecycle.ReceivingState;

    var nextOwner = this.pendingOwner;
    var nextState = this.pendingState;
    if (nextState == null) nextState = this.state;
    this.pendingState = null;

    try {
      if (pendingForceUpdate || this.shouldComponentUpdate(nextProps, nextState, nextContext)) {

        pendingForceUpdate = false;
        this._performComponentUpdate( 
          nextProps, 
          nextOwner, 
          nextState, 
          nextContext, 
          transaction);
      } else {
        props = nextProps;
        state = nextState;
        context = nextContext;
      }

    } catch(e:js.Error) {
      trace(e.stack);
    }

    compositeLifecycleState = null;
  }

  public override function performUpdateIfNecessary() {
    var _state = compositeLifecycleState;
    if (_state == CompositeLifecycle.Mounting || _state == CompositeLifecycle.ReceivingProps) {
      return;
    } 
    return super.performUpdateIfNecessary();
  }
  
}