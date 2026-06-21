<?php

namespace App\GraphQL\Types;

use App\Models\User;
use GraphQL\Type\Definition\Type;
use Rebing\GraphQL\Support\Type as GraphQLType;

class UserType extends GraphQLType
{
    protected $attributes = [
        'name'        => 'User',
        'description' => 'A user',
        'model'       => User::class,
    ];

    public function fields(): array
    {
        return [
            'id' => [
                'type'        => Type::nonNull(Type::int()),
                'description' => 'ID of the user',
            ],
            'name' => [
                'type'        => Type::nonNull(Type::string()),
                'description' => 'Name of the user',
            ],
            'email' => [
                'type'        => Type::nonNull(Type::string()),
                'description' => 'Email of the user',
            ],
            'created_at' => [
                'type'        => Type::string(),
                'description' => 'Created at timestamp',
            ],
            'updated_at' => [
                'type'        => Type::string(),
                'description' => 'Updated at timestamp',
            ],
        ];
    }
}
