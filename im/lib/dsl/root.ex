defmodule Dsl.Root do
  use Spark.Dsl.Extension, sections: [%Spark.Dsl.Section{
    top_level?: true,
    name: :root,
    describe: "Root section defining the message type and processes.",
    schema: [
      messageType: [
        type: {:or, [:atom, :string, :struct]},
        required: true,
        doc: "The type of messages the system handles. Every message has to be this type."
      ],
      allowCrash: [
        type: :boolean,
        doc: "If crashing of the nodes is enabled."
      ],
      lossyNetwork: [
        type: :boolean,
        doc: "If loosing messages in the network is enabled."
      ],
      successLabel: [
        type: {:list, :atom},
        doc: "Specifies the multi action for the `done` label."
      ],
      failedLabel: [
        type: {:list, :atom},
        doc: "Specifies the multi action for the `fail` label."
      ],
      fifoNetwork: [
        type: :boolean,
        doc: "Specifies if the network layer should be configured with first-in-first-out messages, or to use sets."
      ],
      customLabels: [
        type: {:map, :atom, {:list, :atom}},
        doc: "The type of messages the system handles. Every message has to be this type."
      ],
    ],
    entities: [
      Dsl.Entities.Process.process
    ]
  }]

end
