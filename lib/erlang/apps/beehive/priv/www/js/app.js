(function($) {
    
  var app = $.sammy(function() {
    this.element_selector = '#main';    
    this.use(Sammy.Haml);

    this.before(function() {
      var context = this;
    });

		this.get('#/', function(context) {
			this.redirect('#/overview');
		});
		
		this.get('#/overview', function(context) {
      context.app.swap('');
			this.partial('haml/overview.haml');
    });

		this.get('#/events', function(context) {
		  $.ajax({
				type: "GET",
				async: false,
				url: "/events.json",
				dataType: "json",
				success: function(data){
					context.events = data.events;
				}
		  });
		  
		  console.log(context.events);
		  
			context.app.swap('');
			this.partial('haml/events.haml');
		});
		
		this.get('#/apps', function(context) {
			$.ajax({
				type: "GET",
				async: false,
				url: "/apps.json",
				dataType: "json",
				success: function(data){
					context.apps = data.apps;
				}
		  });
						
      context.app.swap('');
			this.partial('haml/apps.haml');
		});
		
		this.get('#/bees', function(context) {
		  $.ajax({
				type: "GET",
				async: false,
				url: "/bees.json",
				dataType: "json",
				success: function(data){
					context.bees = data.bees;
				}
		  });
		  
			context.app.swap('');
			this.partial('haml/bees.haml');
		});
		
		this.get('#/log', function(context) {
			context.app.swap('');
			this.partial('haml/log.haml');
		});
    
  });
  
  $(function() {
    app.run('#/');
  });
  
})(jQuery);