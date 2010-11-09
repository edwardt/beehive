require 'rest_client'
require "json/pure"

module BeehiveClient
  module Rest

     # REST Methods
    def get(path, params = {})
      uri = "http://#{host}/#{path}"
      r = unless params.empty?
            RestClient.get(uri, {:params => params})
          else
            RestClient.get(uri)
          end
      JSON.parse(r)
    end

     def post(path, params={})
       j = RestClient.post("http://#{host}/#{path}", params.to_json)
       handle_response(j)
     end

     def put(path, params={})
       j = RestClient.put("http://#{host}/#{path}", params.to_json)
       handle_response(j)
     end

     def delete(path)
       j = RestClient.delete("http://#{host}/#{path}")
       handle_response(j)
     end


     private

     def handle_response(resp)
       r = JSON.parse(resp)
        if r["error"]
          if r["error"] == "There was a problem authenticating"
            raise StandardError.new("
  There was an error authenticating
  Check your credentials
            ")
          else
            raise StandardError.new(r["error"])
          end
        else
          return r
        end
     end
  end
end
