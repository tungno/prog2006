// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // Specifies the compiler version

// DEfine the HelloName smart contract
contract HelloName {
    // Declare an event to emit the message with the name provided
    event HelloEvent(string message); 

    // Function to emit the Hello event with a personalized message
    function sayHello(string memory _name) public {
        // Concatenate "Hello" with the provided name and emit the event
        string memory greeting = string(abi.encodePacked("Hello, ", _name, "!")); 
        emit HelloEvent(greeting);
    }
}
