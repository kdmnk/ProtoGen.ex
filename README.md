# ProtoGen.Ex
Tool to generate Elixir code with mcrl2 specification 

# Usage guide

1. To create a new specification, create a new module and write ’use Dsl.Im, extensions: [Dsl.Root]’. This allows to write the Elixir module with the syntax defined by the DSL.
2. The compiled protocol structure can be inspected with `Conf.getConf(ModuleName)`.
3. The protocol can be translated to mCRL2 or Elixir by calling `Gen.GenEx.main(ModuleName)`
or `Gen.GenMcrl2.main(ModuleName)`. The files are generated under the folder ’generated’, in a new folder with the name of the protocol. Elixir generation creates a new mix project. The generated files are in folder `lib` under the project. The mCRL2 file is placed in the same project under the folder ’mcrl2’ and with the name `specs.mcrl2`.
4. To configure the Elixir modules to run in a distributed environment using clusters, take a look at the example setup for the [RaftLeaderElection protocol](im/generated/raftLeaderElection/lib/raftLeaderElection/application.ex). Start each node by `iex –name hostname -S mix`. Replace `hostname` by an address configured in the `application.ex`. The protocol can be started using the API modules: e.g. `ServerApi.start()`.
5. To analyse the mCRL2 model, the mCRL2 toolset can be used on the `specs.mcrl2` file. Properties can be checked against the specification by placing them in a new file. There is a [simple bash script](im/mcrl2_analyse.sh) available to verify a property placed in `specs.mcf` against the `specs.mcrl2` model, and display a witness or a counter example transition system. 

Please refer to the paper ['Model-based development and analysis of distributed systems with Elixir and mCRL2'](https://drive.google.com/file/d/1TQCLIkj8u3akF0L4LcrkJGQ75i_8VdVn/view?usp=sharing) for more details and known issues. 

# Academic Abstract: 
In complex, distributed systems, understanding and ensuring the correctness of software be-
haviour is a complex challenge.

Formal Specification-Driven Development (FSDD) [1] combines the method of Test-Driven
Development (TDD) with formal methods. In FSDD, a formal specification is needed to generate
unit tests and some parts of the implementation.

However, writing formal specifications is associated with a steep learning curve that discour-
age programmers from using formal methods in practice. Developers working with Elixir lack
modern, automated tools that can provide insights into their systems without requiring deep
expertise in model checking.

To support programmers in using an approach similar to FSDD, Steenman, E. [2] defined a
high-level language, which is automatically transformed into both a formal model and an imple-
mentation in Java. The model is implemented in the formal specification language mCRL2 that
is designed for specifying, analysing, and verifying concurrent systems and protocols. Steenman
demonstrated that using this high-level language to create formally verifiable code is feasible for
simpler scenarios, such as a system controlling traﬀic lights.

In this project, we developed Steenman’s approach further by focusing on distributed pro-
tocols. Concretely, our research can be summarized in the following question: To what extent
can a high-level language be developed to specify distributed protocols that enable the generation
of both an mCRL2 formal model and an Elixir implementation with identical behaviour, while
addressing the challenges of language design, formal model simulation and implementation fi-
delity? This question has multiple aspects: How can the high-level language be designed to
facilitate the generation of both the formal model and the implementation? How can the formal
model be designed to simulate real distributed systems while also making it easy to analyse
the system behaviour? How can the implementation be designed in such a way that the pro-
gram’s behaviour follows the rules of the formal model? And how complex can the protocols
this approach supports be?

During the project, we developed a high-level domain-specific-language (DSL) embedded in
Elixir to specify distributed protocols with special Elixir syntax. The specified protocols are
based on different processes, each containing multiple states. In each state, the processes may
receive certain messages that trigger behaviours specified by using different commands. These
commands are accessing and modifying data in the processes (like send message command,
if-then-else command, etc.).

As the behaviour of Elixir programs and mCRL2 specifications are fundamentally different,
we made it easier to compare their semantics by separating the control flow (processes, states,
receiving messages) and the data flow (other commands) in the system. In this semi-formal
approach, we mapped the behaviour of the protocol states and their changes to a nondeterminis-
tic automaton, making the foundation for specifying the same protocol behaviour in Elixir and
in mCRL2. After that, we compared the behaviour of the different commands in both output
languages, showing that they modify the data the same way.

After the input and output languages are defined, we implemented the input DSL using a
library called Spark and the logic to generate the output Elixir and mCRL2 files. The tool
currently supports protocols that contain basic instructions like sending/receiving messages,
broadcasting messages, and structures like if-then-else or internal choices. The choices are made
by the mCRL2 model in-deterministically or made by the user running the Elixir implementation.
To communicate with the user, an interface is designed for Elixir.

The generated formal model can be analysed by configuring different environments. The
underlying network layer can be specified to enable the possibility of losing messages or swapping
the message ordering. Processes can also be configured to enable the possibility of crashing.
With these options, a protocol specification can be tested against these different scenarios.
To evaluate the features of the tool and justify the approach, we specified and analysed
three different protocols in increasing complexity: addition, two-phased commit, and simplified
RAFT protocol. We demonstrated how the mCRL2 toolset might be used on the generated
formal specifications to analyse how the systems behave with different configurations. As an
example, we showed that our RAFT specification is able to elect leaders even if some nodes
crash. We also show how nodes can be generated in Elixir and how they can be configured to
run in a distributed environment.

This approach advances our overarching goal of helping developers produce industry code
supported by formal methods. By generating formal models together with the executable code,
the developers may gain a deeper understanding and ensure the reliability and correctness of
their systems, leading to more robust and dependable software.

[1] T. Fofung, “Formal specification driven development,” 2015.

[2] E. Steenman, “Agile development using formal methods,” 2016.