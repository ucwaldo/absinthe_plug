defmodule Absinthe.Plug.TransportBatchingTest do
  use ExUnit.Case, async: true
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema

  @relay_foo_result [
    %{"id" => "1", "payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{"id" => "2", "payload" => %{"data" => %{"item" => %{"name" => "Bar"}}}}
  ]

  @relay_variable_query """
  [{
    "id": "1",
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "foo"}
  }, {
    "id": "2",
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "bar"}
  }]
  """

  @relay_query """
  [{
    "id": "1",
    "query": "query Index { item(id: \\"foo\\") { name } }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query Index { item(id: \\"bar\\") { name } }",
    "variables": {}
  }]
  """

  @apollo_foo_result [
    %{"payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{"payload" => %{"data" => %{"item" => %{"name" => "Bar"}}}}
  ]

  @apollo_batch_link_foo_result [
    %{"data" => %{"item" => %{"name" => "Foo"}}},
    %{"data" => %{"item" => %{"name" => "Bar"}}}
  ]

  @apollo_variable_query """
  [{
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "foo"}
  }, {
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "bar"}
  }]
  """

  @apollo_query """
  [{
    "query": "query Index { item(id: \\"foo\\") { name } }",
    "variables": {}
  }, {
    "query": "query Index { item(id: \\"bar\\") { name } }",
    "variables": {}
  }]
  """

  # SIMPLE QUERIES
  test "single batched query in relay-network-layer format works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @relay_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body
  end

  test "single batched query in relay-network-layer format works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @relay_variable_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body
  end

  test "single batched query in apollo format works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @apollo_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @apollo_foo_result == resp_body
  end

  test "single batched query in modern apollo-link-batch-http format works" do
    opts = Absinthe.Plug.init(schema: TestSchema, transport_batch_payload_key: false)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @apollo_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @apollo_batch_link_foo_result == resp_body
  end

  test "single batched query in apollo format works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @apollo_variable_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @apollo_foo_result == resp_body
  end

  test "single batched query in apollo format works with variables, content-type application/x-www-form-urlencoded" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"_json" => @apollo_variable_query})
             |> put_req_header("content-type", "application/x-www-form-urlencoded")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @apollo_foo_result == resp_body
  end

  @fragment_query """
  [{
    "id": "1",
    "query": "query Q { item(id: \\"foo\\") { ...Named } } fragment Named on Item { name }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query P { item(id: \\"bar\\") { ...Named } } fragment Named on Item { name }",
    "variables": {}
  }]
  """

  test "can include fragments" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @fragment_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body
  end

  @fragment_query_with_undefined_field """
  [{
    "id": "1",
    "query": "query Q { item(id: \\"foo\\") { ...Named } } fragment Named on Item { name }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query P { item(id: \\"foo\\") { ...Named } } fragment Named on Item { namep }",
    "variables": {}
  }]
  """
  @fragment_query_with_undefined_field_result [
    %{"id" => "1", "payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{
      "id" => "2",
      "payload" => %{
        "errors" => [
          %{
            "message" => "Cannot query field \"namep\" on type \"Item\". Did you mean \"name\"?",
            "locations" => [%{"line" => 1, "column" => 67}]
          }
        ]
      }
    }
  ]

  test "can include fragments with undefined fields" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @fragment_query_with_undefined_field)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @fragment_query_with_undefined_field_result == resp_body
  end

  @fragment_query_with_undefined_variable """
  [{
    "id": "1",
    "query": "query Q { item(id: \\"foo\\") { ...Named } } fragment Named on Item { name }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query P($id: ID!) { item(id: $id) { ...Named } } fragment Named on Item { name }",
    "variables": {"idx": "foo"}
  }]
  """

  @fragment_query_with_undefined_variable_result [
    %{"id" => "1", "payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{
      "id" => "2",
      "payload" => %{
        "errors" => [
          %{
            "message" => "In argument \"id\": Expected type \"ID!\", found null.",
            "locations" => [%{"line" => 1, "column" => 26}]
          },
          %{
            "message" => "Variable \"id\": Expected non-null, found null.",
            "locations" => [%{"line" => 1, "column" => 9}]
          }
        ]
      }
    }
  ]

  test "can include fragments with undefined variable" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @fragment_query_with_undefined_variable)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @fragment_query_with_undefined_variable_result == resp_body
  end

  test "it can use resolution batching across documents" do
    {:ok, pid} = Counter.start_link(0)
    opts = Absinthe.Plug.init(schema: TestSchema, context: %{counter: pid})

    payload = """
    [{
      "id": "1",
      "query": "{ pingCounter }",
      "variables": {}
    }, {
      "id": "2",
      "query": "{ pingCounter }",
      "variables": {}
    }]
    """

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", payload)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    expected = [
      %{"id" => "1", "payload" => %{"data" => %{"pingCounter" => 1}}},
      %{"id" => "2", "payload" => %{"data" => %{"pingCounter" => 1}}}
    ]

    assert expected == resp_body

    assert 1 == Counter.read(pid)
  end

  test "it can handle batches where some docs have errors" do
    {:ok, pid} = Counter.start_link(0)
    opts = Absinthe.Plug.init(schema: TestSchema, context: %{counter: pid})

    payload = """
    [{
      "id": "1",
      "query": "{asdf }",
      "variables": {}
    }, {
      "id": "2",
      "query": "{ pingCounter }",
      "variables": {"id": "bar"}
    }]
    """

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", payload)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    expected = [
      %{
        "id" => "1",
        "payload" => %{
          "errors" => [
            %{
              "message" => "Cannot query field \"asdf\" on type \"RootQueryType\".",
              "locations" => [%{"line" => 1, "column" => 2}]
            }
          ]
        }
      },
      %{"id" => "2", "payload" => %{"data" => %{"pingCounter" => 1}}}
    ]

    assert expected == resp_body

    assert 1 == Counter.read(pid)
  end

  test "it handles complexity errors" do
    opts = Absinthe.Plug.init(schema: TestSchema, max_complexity: 100, analyze_complexity: true)

    payload = """
    [{
      "id": "1",
      "query": "{ expensive }",
      "variables": {}
    }, {
      "id": "2",
      "query": "{ expensive }",
      "variables": {"id": "bar"}
    }]
    """

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", payload)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    expected = [
      %{
        "id" => "1",
        "payload" => %{
          "errors" => [
            %{
              "message" =>
                "Field expensive is too complex: complexity is 1000 and maximum is 100",
              "locations" => [%{"line" => 1, "column" => 3}]
            },
            %{
              "message" => "Operation is too complex: complexity is 1000 and maximum is 100",
              "locations" => [%{"line" => 1, "column" => 1}]
            }
          ]
        }
      },
      %{
        "id" => "2",
        "payload" => %{
          "errors" => [
            %{
              "message" =>
                "Field expensive is too complex: complexity is 1000 and maximum is 100",
              "locations" => [%{"line" => 1, "column" => 3}]
            },
            %{
              "message" => "Operation is too complex: complexity is 1000 and maximum is 100",
              "locations" => [%{"line" => 1, "column" => 1}]
            }
          ]
        }
      }
    ]

    assert expected == resp_body
  end

  @upload_relay_variable_query [
                                 %{
                                   id: "1",
                                   query: "{uploadTest(fileA: \"a\")}",
                                   variables: %{}
                                 },
                                 %{
                                   id: "2",
                                   query:
                                     "query Upload($file: Upload) {uploadTest(fileA: $file)}",
                                   variables: %{"file" => "a"}
                                 }
                               ]
                               |> Jason.encode!()

  test "single batched query in relay-network-layer format works with variables and uploads" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    upload = %Plug.Upload{}

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"_json" => @upload_relay_variable_query, "a" => upload})
             |> put_req_header("content-type", "multipart/form-data")
             |> plug_parser
             |> absinthe_plug(opts)

    assert [
             %{"id" => "1", "payload" => %{"data" => %{"uploadTest" => "file_a"}}},
             %{"id" => "2", "payload" => %{"data" => %{"uploadTest" => "file_a"}}}
           ] == resp_body
  end

  test "single batched query with operations argument works with variables and uploads" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    upload = %Plug.Upload{}

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"operations" => @upload_relay_variable_query, "a" => upload})
             |> put_req_header("content-type", "multipart/form-data")
             |> plug_parser
             |> absinthe_plug(opts)

    assert [
             %{"id" => "1", "payload" => %{"data" => %{"uploadTest" => "file_a"}}},
             %{"id" => "2", "payload" => %{"data" => %{"uploadTest" => "file_a"}}}
           ] == resp_body
  end

  test "before_send with batched query" do
    opts = Absinthe.Plug.init(schema: TestSchema, before_send: {__MODULE__, :test_before_send})

    assert %{status: 200, resp_body: resp_body} =
             conn =
             conn(:post, "/", @relay_query)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body

    # two docs so it should run twice, one for each doc
    assert_receive({:before_send, _})
    assert_receive({:before_send, _})

    assert conn.private[:user_id] == 1
  end

  @unused_fragment_query_with_directive """
  [{
    "id": "1",
    "query": "query O { items @skip(if: true) { id name child { id name } } }",
    "variables": {}
  },{
    "id": "2",
    "query": "query O { items { id name child { id name } } }",
    "variables": {}
  }]
  """

  @unused_fragment_query_with_directive_result [
    %{"id" => "1", "payload" => %{"data" => %{}}},
    %{
      "id" => "2",
      "payload" => %{
        "data" => %{
          "items" => [
            %{"child" => %{"id" => "bar", "name" => "Bar"}, "id" => "bar", "name" => "Bar"},
            %{"child" => %{"id" => "foo", "name" => "Foo"}, "id" => "foo", "name" => "Foo"}
          ]
        }
      }
    }
  ]

  defmodule CustomSchema.Helpers do
    @child %{id: "foo", name: "Foo"}

    @items %{
      "foo" => %{id: "foo", name: "Foo", child: @child},
      "bar" => %{id: "bar", name: "Bar", child: @child}
    }

    def by_id(_model, ids) do
      @items
      |> Map.values()
      |> Enum.filter(fn item -> item.id in ids end)
    end
  end

  defmodule CustomSchema do
    use Absinthe.Schema

    @child %{id: "foo", name: "Foo"}

    @items %{
      "foo" => %{id: "foo", name: "Foo", child: @child},
      "bar" => %{id: "bar", name: "Bar", child: @child}
    }

    query do
      field :items, list_of(:item) do
        resolve fn _, _ ->
          {:ok, Map.values(@items)}
        end
      end
    end

    object :item do
      field :id, :id
      field :name, :string

      field :child, :child_item do
        resolve fn item, _, _ ->
          batch({CustomSchema.Helpers, :by_id}, item.id, fn batch_results ->
            result = Enum.find(batch_results, fn r -> r.id == item.id end)
            {:ok, result}
          end)
        end
      end
    end

    object :child_item do
      field :id, :id
      field :name, :string
    end
  end

  test "can include unused fragment with skip directive" do
    opts = Absinthe.Plug.init(schema: CustomSchema)

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", @unused_fragment_query_with_directive)
             |> put_req_header("content-type", "application/json")
             |> plug_parser()
             |> absinthe_plug(opts)

    assert @unused_fragment_query_with_directive_result == resp_body
  end

  test "returns 400 with invalid batch structure" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    # list of query strings is invalid
    body = Jason.encode!(["{ item { name } }"])

    assert %{status: 400, resp_body: resp_body} =
             conn(:post, "/", body)
             |> put_req_header("content-type", "application/json")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert resp_body =~ "Expecting a list"
  end

  def test_before_send(conn, val) do
    # just for easy testing
    send(self(), {:before_send, val})

    conn
    |> put_private(:user_id, 1)
  end

  defp absinthe_plug(conn, opts) do
    opts = Map.put(opts, :before_send, {__MODULE__, :test_before_send})
    %{resp_body: body} = conn = Absinthe.Plug.call(conn, opts)

    case Jason.decode(body) do
      {:ok, parsed} -> %{conn | resp_body: parsed}
      _ -> conn
    end
  end
end
