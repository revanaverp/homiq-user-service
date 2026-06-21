<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\RabbitMQService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    // POST /auth/register
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'     => 'required|string|max:255',
            'email'    => 'required|string|email|unique:users',
            'password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        $user = User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'password' => Hash::make($request->password),
        ]);

        // Publish event ke RabbitMQ
        try {
            $rabbitmq = new RabbitMQService();
            $rabbitmq->publish('user.registered', [
                'event'         => 'user.registered',
                'user_id'       => $user->id,
                'name'          => $user->name,
                'email'         => $user->email,
                'registered_at' => $user->created_at,
            ]);
        } catch (\Exception $e) {
            // Log error tapi jangan gagalkan register
            \Log::warning('RabbitMQ publish failed: ' . $e->getMessage());
        }

        return response()->json([
            'success' => true,
            'message' => 'User registered successfully',
            'data'    => [
                'user' => $user
            ]
        ], 201);
    }

    // POST /auth/login
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email'    => 'required|email',
            'password' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid email or password'
            ], 401);
        }

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data'    => [
                'user' => $user
            ]
        ], 200);
    }
}
