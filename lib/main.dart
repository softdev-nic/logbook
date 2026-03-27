 import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum FilterType { all, completed, pending }

class _MyHomePageState extends State<MyHomePage> {
  List<Map<String, Object>> tasks = [];
  List<Map<String, Object>> filteredTasks = [];

  final TextEditingController searchController = TextEditingController();
  FilterType currentFilter = FilterType.all;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tasks') ?? [];

    final loaded = data.map<Map<String, Object>>((item) {
      final parts = item.split('|');
      return {
        'text': parts[0],
        'done': parts.length > 1 ? parts[1] == 'true' : false,
      };
    }).toList();

    setState(() {
      tasks = loaded;
      applyFilters();
    });
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = tasks
        .map((task) => "${task['text']}|${task['done']}")
        .toList();

    await prefs.setStringList('tasks', encoded);
  }

  // 🔥 CORE FILTER LOGIC
  void applyFilters() {
    String query = searchController.text.toLowerCase();

    List<Map<String, Object>> temp = tasks;

    // FILTER BY STATE
    if (currentFilter == FilterType.completed) {
      temp = temp.where((t) => t['done'] as bool).toList();
    } else if (currentFilter == FilterType.pending) {
      temp = temp.where((t) => !(t['done'] as bool)).toList();
    }

    // FILTER BY SEARCH
    if (query.isNotEmpty) {
      temp = temp.where((t) {
        return (t['text'] as String).toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      filteredTasks = temp;
    });
  }

  void showAddTaskDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add Task"),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;

                setState(() {
                  tasks.add({
                    'text': controller.text.trim(),
                    'done': false,
                  });
                  applyFilters();
                });

                saveTasks();
                Navigator.pop(dialogContext);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void deleteTask(int index) {
    final task = filteredTasks[index];

    setState(() {
      tasks.remove(task);
      applyFilters();
    });

    saveTasks();
  }

  void editTask(int index) {
    final task = filteredTasks[index];
    final controller =
        TextEditingController(text: task['text'] as String);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit Task"),
          content: TextField(controller: controller),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;

                setState(() {
                  task['text'] = controller.text.trim();
                  applyFilters();
                });

                saveTasks();
                Navigator.pop(dialogContext);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget filterButton(String label, FilterType type) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          currentFilter = type;
          applyFilters();
        });
      },
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Book"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: showAddTaskDialog,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // SEARCH
            TextField(
              controller: searchController,
              onChanged: (_) => applyFilters(),
              decoration: const InputDecoration(
                hintText: "Search tasks...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            // 🔥 FILTER BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                filterButton("All", FilterType.all),
                filterButton("Completed", FilterType.completed),
                filterButton("Pending", FilterType.pending),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];

                  return Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: task['done'] as bool,
                        onChanged: (value) {
                          setState(() {
                            task['done'] = value ?? false;
                            applyFilters();
                          });
                          saveTasks();
                        },
                      ),
                      title: Text(task['text'] as String),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => editTask(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => deleteTask(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}